// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

struct Approval {
    uint256 deadline;
    uint8 v; // Changes at each new signature because of ERC20 Permit nonce
    bytes32 r;
    bytes32 s;
}

struct Intent {
    address recipient;
    address rwaToken;
    uint256 amountInTokenDecimals;
    uint256 deadline;
    bytes signature;
}

interface IDaoCollateral {
    /*//////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when tokens are swapped.
    /// @param owner The address of the owner
    /// @param tokenSwapped The address of the token swapped
    /// @param amount The amount of tokens swapped
    /// @param amountInUSD The amount in USD
    event Swap(
        address indexed owner, address indexed tokenSwapped, uint256 amount, uint256 amountInUSD
    );

    /// @notice Emitted when tokens are redeemed.
    /// @param redeemer The address of the redeemer
    /// @param rwaToken The address of the rwaToken
    /// @param amountRedeemed The amount of tokens redeemed
    /// @param returnedRwaAmount The amount of rwaToken returned
    /// @param stableFeeAmount The amount of stableToken fee
    event Redeem(
        address indexed redeemer,
        address indexed rwaToken,
        uint256 amountRedeemed,
        uint256 returnedRwaAmount,
        uint256 stableFeeAmount
    );

    /// @notice Emitted when an intent is matched.
    /// @param owner The address of the owner
    /// @param nonce The nonce of the intent
    /// @param tokenSwapped The address of the token swapped
    /// @param amountInTokenDecimals The amount in token decimals
    /// @param amountInUSD The amount in USD
    event IntentMatched(
        address indexed owner,
        uint256 indexed nonce,
        address indexed tokenSwapped,
        uint256 amountInTokenDecimals,
        uint256 amountInUSD
    );

    /// @notice Emitted when an intent and associated nonce is consumed.
    /// @param owner The address of the owner
    /// @param nonce The nonce of the intent
    /// @param tokenSwapped The address of the token swapped
    /// @param totalAmountInTokenDecimals The total amount in token decimals
    event IntentConsumed(
        address indexed owner,
        uint256 indexed nonce,
        address indexed tokenSwapped,
        uint256 totalAmountInTokenDecimals
    );

    /// @notice Emitted when a nonce is invalidated.
    /// @param signer The address of the signer
    /// @param nonceInvalidated The nonce of the intent
    event NonceInvalidated(address indexed signer, uint256 indexed nonceInvalidated);

    /// @notice Emitted when redeem functionality is paused.
    event RedeemPaused();

    /// @notice Emitted when redeem functionality is unpaused.
    event RedeemUnPaused();

    /// @notice Emitted when swap functionality is paused.
    event SwapPaused();

    /// @notice Emitted when swap functionality is unpaused.
    event SwapUnPaused();

    /// @notice Emitted when the Counter Bank Run (CBR) mechanism is activated.
    /// @param cbrCoef The Counter Bank Run (CBR) coefficient.
    event CBRActivated(uint256 cbrCoef);

    /// @notice Emitted when the Counter Bank Run (CBR) mechanism is deactivated.
    event CBRDeactivated();

    /// @notice Emitted when the redeem fee is updated.
    /// @param redeemFee The new redeem fee.
    event RedeemFeeUpdated(uint256 redeemFee);

    /// @notice Emitted when the nonce threshold is set.
    /// @param newThreshold The new threshold value
    event NonceThresholdSet(uint256 newThreshold);

    /*//////////////////////////////////////////////////////////////
                                Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Activates the Counter Bank Run (CBR) mechanism.
    /// @param coefficient the CBR coefficient to activate
    function activateCBR(uint256 coefficient) external;

    /// @notice Deactivates the Counter Bank Run (CBR) mechanism.
    function deactivateCBR() external;

    /// @notice Sets the redeem fee.
    /// @param _redeemFee The new redeem fee to set.
    function setRedeemFee(uint256 _redeemFee) external;

    /// @notice Pauses the redeem functionality.
    function pauseRedeem() external;

    /// @notice Unpauses the redeem functionality.
    function unpauseRedeem() external;

    /// @notice Pauses the swap functionality.
    function pauseSwap() external;

    /// @notice Unpauses the swap functionality.
    function unpauseSwap() external;

    /// @notice Pauses the contract.
    function pause() external;

    /// @notice Unpauses the contract.
    function unpause() external;

    /// @notice  swap method
    /// @dev     Function that enable you to swap your rwaToken for stablecoin
    /// @dev     Will exchange RWA (rwaToken) for USD0 (stableToken)
    /// @param   rwaToken  address of the token to swap
    /// @param   amount  amount of rwaToken to swap
    /// @param   minAmountOut minimum amount of stableToken to receive
    function swap(address rwaToken, uint256 amount, uint256 minAmountOut) external;

    /// @notice  swap method with permit
    /// @dev     Function that enable you to swap your rwaToken for stablecoin with permit
    /// @dev     Will exchange RWA (rwaToken) for USD0 (stableToken)
    /// @param   rwaToken  address of the token to swap
    /// @param   amount  amount of rwaToken to swap
    /// @param   deadline The deadline for the permit
    /// @param   v The v value for the permit
    /// @param   r The r value for the permit
    /// @param   s The s value for the permit
    function swapWithPermit(
        address rwaToken,
        uint256 amount,
        uint256 minAmountOut,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /// @notice  redeem method
    /// @dev     Function that enable you to redeem your stable token for rwaToken
    /// @dev     Will exchange USD0 (stableToken) for RWA (rwaToken)
    /// @param   rwaToken address of the token that will be sent to the you
    /// @param   amount  amount of stableToken to redeem
    /// @param   minAmountOut minimum amount of rwaToken to receive
    function redeem(address rwaToken, uint256 amount, uint256 minAmountOut) external;

    /// @notice Swap RWA for USDC through offers on the SwapperContract
    /// @dev Takes USYC, mints USD0 and provides it to the Swapper Contract directly
    /// Sends USD0 to the offer's creator and sends USDC to the recipient
    /// @dev the recipient Address to receive the USDC is msg.sender
    /// @param rwaToken Address of the RWA to swap for USDC
    /// @param amountInTokenDecimals Address of the RWA to swap for USDC
    /// @param orderIdsToTake orderIds to be taken
    /// @param approval ERC20Permit approval data and signature of data
    /// @param partialMatching flag to allow partial matching
    function swapRWAtoStbc(
        address rwaToken,
        uint256 amountInTokenDecimals,
        bool partialMatching,
        uint256[] calldata orderIdsToTake,
        Approval calldata approval
    ) external;

    /// @notice Swap RWA for USDC through offers on the SwapperContract
    /// @dev Takes USYC, mints USD0 and provides it to the Swapper Contract directly
    /// Sends USD0 to the offer's creator and sends USDC to the recipient
    /// @dev the recipient Address to receive the USDC is the offer's creator
    /// @param orderIdsToTake orderIds to be taken
    /// @param approval ERC20Permit approval data and signature of data
    /// @param intent Intent data and signature of data
    /// @param partialMatching flag to allow partial matching
    function swapRWAtoStbcIntent(
        uint256[] calldata orderIdsToTake,
        Approval calldata approval,
        Intent calldata intent,
        bool partialMatching
    ) external;

    // * Getter functions

    /// @notice get the redeem fee percentage
    /// @return the fee value
    function redeemFee() external view returns (uint256);

    /// @notice check if the CBR (Counter Bank Run) is activated
    /// @dev flag indicate the status of the CBR (see documentation for more details)
    /// @return the status of the CBR
    function isCBROn() external view returns (bool);

    /// @notice Returns the cbrCoef value.
    function cbrCoef() external view returns (uint256);

    /// @notice get the status of pause for the redeem function
    /// @return the status of the pause
    function isRedeemPaused() external view returns (bool);

    /// @notice get the status of pause for the swap function
    /// @return the status of the pause
    function isSwapPaused() external view returns (bool);

    // * Restricted functions

    /// @notice  redeem method for DAO
    /// @dev     Function that enables DAO to redeem stableToken for rwaToken
    /// @dev     Will exchange USD0 (stableToken) for RWA (rwaToken)
    /// @param   rwaToken address of the token that will be sent to the you
    /// @param   amount  amount of stableToken to redeem
    function redeemDao(address rwaToken, uint256 amount) external;

    /// @notice Invalidates the current nonce for the message sender
    /// @dev This function increments the nonce counter for the msg.sender and emits a NonceInvalidated event
    function invalidateNonce() external;

    /// @notice Invalidates all nonces up to a certain value for the message sender
    /// @dev This function increments the nonce counter for the msg.sender and emits a NonceInvalidated event
    function invalidateUpToNonce(uint256 newNonce) external;

    /// @notice Returns the amount of tokens taken for the current nonce
    /// @param owner The address of the owner
    /// @return The amount of tokens taken for the current nonce
    function orderAmountTakenCurrentNonce(address owner) external view returns (uint256);

    /// @notice Set the lower bound for the intent nonce to be considered consumed
    /// @dev An intent with an amount less than this threshold after a partial match will be invalidated by incrementing the nonce
    /// @dev emits a NonceThresholdSet event
    /// @param threshold The new threshold value
    function setNonceThreshold(uint256 threshold) external;

    /// @notice Check the current threshold for the intent nonce to be considered consumed
    /// @return The current threshold value
    function nonceThreshold() external view returns (uint256);
}
