// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {
    UUPSUpgradeable
} from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {
    IUniversalRouter
} from "@uniswap/universal-router/contracts/interfaces/IUniversalRouter.sol";
import { IPermit2 } from "@permit2/src/interfaces/IPermit2.sol";
import {
    IAllowanceTransfer
} from "@permit2/src/interfaces/IAllowanceTransfer.sol";
import {
    ISignatureTransfer
} from "@permit2/src/interfaces/ISignatureTransfer.sol";

import { IFlooring } from "./interface/IFlooring.sol";
import { OwnedUpgradeable } from "./library/OwnedUpgradeable.sol";
import { CurrencyTransfer } from "./library/CurrencyTransfer.sol";
import { ERC721Transfer } from "./library/ERC721Transfer.sol";
import { TicketRecord, SafeBoxKey, SafeBox } from "./logic/Structs.sol";
import "./logic/SafeBox.sol";
import "./Errors.sol";
import "./Constants.sol";
import { FloorGetter } from "./FloorGetter.sol";
import "./interface/IWETH9.sol";
import "./base/Multicall.sol";
import "./logic/CollectionKey.sol";

contract FloorPeriphery is OwnedUpgradeable, UUPSUpgradeable, IERC721Receiver {
    using CollectionKeyLib for CollectionKey;

    error WrongEthSender();
    error InsufficientWETH9();
    error InvalidParameter();
    error InvalidClaimFee();
    error InvalidPermitOwner();

    IUniversalRouter public immutable UNIVERSAL_ROUTER;
    IPermit2 public immutable PERMIT2;

    address public immutable floor;
    address public immutable floorGetter;

    struct FloorFragment {
        CollectionKey collectionKey;
        uint256[] tokenIds;
    }

    struct FloorClaim {
        CollectionKey collectionKey;
        uint256[] tokenIds;
        uint256 maxClaimFee;
        uint256 claimCnt;
    }

    struct UniversalRouterExecute {
        bytes commands;
        bytes[] inputs;
        uint256 deadline;
    }

    enum TransferWay {
        /// Permitted before, Transfer via Permit2
        PermittedTransfer,
        /// Permit allowance and Transfer via Permit2
        AllowanceTransfer,
        /// Transfer with signature via Permit2
        SignatureTransfer,
        /// Native ETH, No more actions to transfer
        NativeTransfer
    }

    /// Signature Transfer via Permit2, permit owner is `msg.sender`
    struct SignPermitTransfer {
        ISignatureTransfer.PermitTransferFrom permit;
        ISignatureTransfer.SignatureTransferDetails transferDetails;
        bytes signature;
    }

    /// Permit and transfer `token` from `msg.sender` to `to`
    /// permit owner is `msg.sender`
    struct AllowancePermitTransfer {
        IAllowanceTransfer.PermitSingle permit;
        bytes signature;
        address to;
        uint160 amount;
        address token;
    }

    /// permit owner is `msg.sender`
    struct SignPermitBatchTransfer {
        ISignatureTransfer.PermitBatchTransferFrom permit;
        ISignatureTransfer.SignatureTransferDetails[] transferDetails;
        bytes signature;
    }

    /// permit owner is `msg.sender`
    struct AllowancePermitBatchTransfer {
        IAllowanceTransfer.PermitBatch permit;
        bytes signature;
        IAllowanceTransfer.AllowanceTransferDetails[] transferDetails;
    }

    constructor(
        address _floor,
        address _floorGetter,
        address _universalRouter,
        address permit2
    ) payable {
        floor = _floor;
        floorGetter = _floorGetter;
        UNIVERSAL_ROUTER = IUniversalRouter(_universalRouter);
        PERMIT2 = IPermit2(permit2);
    }

    // required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize() public initializer {
        __Owned_init();
        __UUPSUpgradeable_init();
    }

    function fragmentAndSell(
        FloorFragment memory fragmentParam,
        UniversalRouterExecute calldata swapParam,
        TransferWay transferWay,
        bytes calldata transferParam
    ) external payable {
        _fragment(fragmentParam);
        /// transfer selling tokens to UNIVERSAL_ROUTER
        _executeTransfer(transferWay, transferParam);
        /// swap
        UNIVERSAL_ROUTER.execute(
            swapParam.commands,
            swapParam.inputs,
            swapParam.deadline
        );
    }

    function fragmentAndSell(
        FloorFragment[] memory fragmentParams,
        UniversalRouterExecute calldata swapParam,
        TransferWay transferWay,
        bytes calldata transferParam
    ) external payable {
        uint256 batchLen = fragmentParams.length;
        for (uint256 i; i < batchLen; ) {
            _fragment(fragmentParams[i]);
            unchecked {
                ++i;
            }
        }
        /// transfer selling tokens to UNIVERSAL_ROUTER
        _executeBatchTransfer(transferWay, transferParam);
        /// swap
        UNIVERSAL_ROUTER.execute(
            swapParam.commands,
            swapParam.inputs,
            swapParam.deadline
        );
    }

    function _fragment(FloorFragment memory param) private {
        (CollectionKey collectionKey, uint256[] memory tokenIds) = (
            param.collectionKey,
            param.tokenIds
        );
        address collectionContract = collectionKey.contractAddr();

        /// approve all nfts for Floor
        approveAllERC721(collectionContract, floor);
        /// transfer tokens into this
        ERC721Transfer.safeBatchTransferFrom(
            collectionContract,
            msg.sender,
            address(this),
            tokenIds
        );
        /// fragment
        IFlooring(floor).fragmentNFTs(collectionKey, tokenIds, msg.sender);
    }

    function buyAndClaimExpired(
        FloorClaim memory claimParams,
        UniversalRouterExecute calldata swapParam,
        TransferWay transferWay,
        bytes calldata transferParam
    ) external payable {
        IFlooring(floor).tidyExpiredNFTs(
            claimParams.collectionKey.id(),
            claimParams.tokenIds
        );
        buyAndClaimVault(claimParams, swapParam, transferWay, transferParam);
    }

    function buyAndClaimExpired(
        FloorClaim[] memory claimParams,
        UniversalRouterExecute calldata swapParam,
        TransferWay transferWay,
        bytes calldata transferParam
    ) external payable {
        uint256 batchLen = claimParams.length;
        for (uint256 i; i < batchLen; ) {
            IFlooring(floor).tidyExpiredNFTs(
                claimParams[i].collectionKey.id(),
                claimParams[i].tokenIds
            );
            unchecked {
                ++i;
            }
        }
        buyAndClaimVault(claimParams, swapParam, transferWay, transferParam);
    }

    function buyAndClaimVault(
        FloorClaim memory claimParams,
        UniversalRouterExecute calldata swapParam,
        TransferWay transferWay,
        bytes calldata transferParam
    ) public payable {
        _executeTransfer(transferWay, transferParam);
        _executeSwap(transferWay, swapParam);
        _claim(claimParams);
    }

    function buyAndClaimVault(
        FloorClaim[] memory claimParams,
        UniversalRouterExecute calldata swapParam,
        TransferWay transferWay,
        bytes calldata transferParam
    ) public payable {
        _executeBatchTransfer(transferWay, transferParam);
        _executeSwap(transferWay, swapParam);

        uint256 batchLen = claimParams.length;
        for (uint256 i; i < batchLen; ) {
            _claim(claimParams[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _claim(FloorClaim memory param) private {
        (CollectionKey collectionKey, uint256 claimCnt, uint256 maxClaimFee) = (
            param.collectionKey,
            param.claimCnt,
            param.maxClaimFee
        );

        address fragmentToken = FloorGetter(floorGetter).fragmentTokenOf(
            collectionKey.id()
        );

        if (maxClaimFee > 0) {
            approveAllERC20(fragmentToken, floor, maxClaimFee);
            IFlooring(floor).addTokens(
                address(this),
                fragmentToken,
                maxClaimFee
            );
        }

        uint256 claimCost = IFlooring(floor).claimRandomNFT(
            collectionKey.id(),
            claimCnt,
            maxClaimFee,
            msg.sender
        );
        /// no extra fee or fee matching
        if (maxClaimFee > 0 && maxClaimFee != claimCost)
            revert InvalidClaimFee();
    }

    function _executeSwap(
        TransferWay way,
        UniversalRouterExecute calldata swapParam
    ) private {
        if (way == TransferWay.NativeTransfer && address(this).balance > 0) {
            /// buy with eth
            UNIVERSAL_ROUTER.execute{ value: address(this).balance }(
                swapParam.commands,
                swapParam.inputs,
                swapParam.deadline
            );
        } else {
            UNIVERSAL_ROUTER.execute(
                swapParam.commands,
                swapParam.inputs,
                swapParam.deadline
            );
        }
    }

    function _executeTransfer(
        TransferWay way,
        bytes calldata transferParam
    ) private {
        if (way == TransferWay.NativeTransfer) return;

        if (way == TransferWay.PermittedTransfer) {
            (address to, uint160 amount, address token) = abi.decode(
                transferParam,
                (address, uint160, address)
            );
            PERMIT2.transferFrom(msg.sender, to, amount, token);
        } else if (way == TransferWay.AllowanceTransfer) {
            AllowancePermitTransfer memory param = abi.decode(
                transferParam,
                (AllowancePermitTransfer)
            );
            PERMIT2.permit(msg.sender, param.permit, param.signature);
            PERMIT2.transferFrom(
                msg.sender,
                param.to,
                param.amount,
                param.token
            );
        } else if (way == TransferWay.SignatureTransfer) {
            SignPermitTransfer memory param = abi.decode(
                transferParam,
                (SignPermitTransfer)
            );
            /// transfer selling tokens to UNIVERSAL_ROUTER
            PERMIT2.permitTransferFrom(
                param.permit,
                param.transferDetails,
                msg.sender,
                param.signature
            );
        } else {
            revert InvalidParameter();
        }
    }

    function _executeBatchTransfer(
        TransferWay way,
        bytes calldata transferParam
    ) private {
        if (way == TransferWay.NativeTransfer) return;

        if (way == TransferWay.PermittedTransfer) {
            IAllowanceTransfer.AllowanceTransferDetails[] memory param = abi
                .decode(
                    transferParam,
                    (IAllowanceTransfer.AllowanceTransferDetails[])
                );
            for (uint256 i; i < param.length; ++i) {
                if (param[i].from != msg.sender) revert InvalidPermitOwner();
            }
            PERMIT2.transferFrom(param);
        } else if (way == TransferWay.AllowanceTransfer) {
            AllowancePermitBatchTransfer memory param = abi.decode(
                transferParam,
                (AllowancePermitBatchTransfer)
            );
            PERMIT2.permit(msg.sender, param.permit, param.signature);
            for (uint256 i; i < param.transferDetails.length; ++i) {
                if (param.transferDetails[i].from != msg.sender)
                    revert InvalidPermitOwner();
            }
            PERMIT2.transferFrom(param.transferDetails);
        } else if (way == TransferWay.SignatureTransfer) {
            SignPermitBatchTransfer memory param = abi.decode(
                transferParam,
                (SignPermitBatchTransfer)
            );
            /// transfer selling tokens to UNIVERSAL_ROUTER
            PERMIT2.permitTransferFrom(
                param.permit,
                param.transferDetails,
                msg.sender,
                param.signature
            );
        } else {
            revert InvalidParameter();
        }
    }

    function approveAllERC20(
        address token,
        address spender,
        uint256 desireAmount
    ) private {
        if (desireAmount == 0) {
            return;
        }
        uint256 allowance = IERC20(token).allowance(address(this), spender);
        if (allowance < desireAmount) {
            IERC20(token).approve(spender, type(uint256).max);
        }
    }

    function approveAllERC721(address collection, address spender) private {
        bool approved = IERC721(collection).isApprovedForAll(
            address(this),
            spender
        );
        if (!approved) {
            IERC721(collection).setApprovalForAll(spender, true);
        }
    }

    function onERC721Received(
        address,
        /*operator*/ address,
        /*from*/ uint256,
        /*tokenId*/ bytes calldata /*data*/
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    receive() external payable {
        if (msg.sender != address(UNIVERSAL_ROUTER)) revert WrongEthSender();
    }
}
