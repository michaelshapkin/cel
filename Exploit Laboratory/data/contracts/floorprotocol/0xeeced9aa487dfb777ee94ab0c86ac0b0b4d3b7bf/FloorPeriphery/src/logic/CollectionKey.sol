// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice The key used to uniquely identify a collection, where the range includes both left and right boundaries.
///         As some contracts may have multiple collections within one contract based on token ranges.
///         Currently, it consists of three components:
///         - The lowest 20 bytes represent the contract address of the collection.
///         - [optional] The next 6 bytes indicate the starting value of the range.
///         - [optional] The following 6 bytes represent the ending value of the range.
type CollectionKey is bytes32;

library CollectionKeyLib {
    /// @notice Converts a CollectionKey to an address identifier.
    /// @param key The CollectionKey to be converted.
    /// @return An address identifier derived from the CollectionKey.
    function id(CollectionKey key) internal pure returns (address) {
        // Unwrap the CollectionKey to extract its data
        uint256 data = uint256(CollectionKey.unwrap(key));

        // Check if the contract address can be directly obtained from the data
        if ((data >> 160) == 0) {
            // If the upper 96 bits are zero, directly convert to address
            return address(uint160(data));
        } else {
            // If the upper 96 bits are non-zero, derive the address using keccak256
            return
                address(
                    uint160(
                        uint256(
                            keccak256(
                                abi.encodePacked(
                                    uint160(data),
                                    uint48(data >> 160),
                                    uint48(data >> 208)
                                )
                            )
                        )
                    )
                );
        }
    }

    function contractAddr(CollectionKey key) internal pure returns (address) {
        return address(uint160(uint256(CollectionKey.unwrap(key))));
    }

    /// @notice Checks if a given range of tokenIds is valid for the specified CollectionKey.
    /// @param key The CollectionKey to validate against.
    /// @param first The starting tokenId of the range to be checked.
    /// @param last The ending tokenId of the range to be checked.
    /// @return A boolean indicating whether the specified range of tokenIds is valid.
    function isValidTokenList(
        CollectionKey key,
        uint256 first,
        uint256 last
    ) internal pure returns (bool) {
        uint256 data = uint256(CollectionKey.unwrap(key));

        // Check if the range of tokenIds falls within the specified CollectionKey
        return
            (data >> 160) == 0 ||
            (first <= last &&
                uint48(data >> 160) <= first &&
                last <= uint48(data >> 208));
    }

    /// @notice Converts a collection contract address to a CollectionKey.
    /// @param collectionContract The address of the collection contract to be converted.
    /// @return A CollectionKey representing the given collection contract address.
    function toKey(
        address collectionContract
    ) internal pure returns (CollectionKey) {
        return
            CollectionKey.wrap(bytes32(uint256(uint160(collectionContract))));
    }

    function toKey(
        address collectionContract,
        uint48 left,
        uint48 right
    ) internal pure returns (CollectionKey) {
        require(left < right);
        uint256 data = uint160(collectionContract) |
            (uint256(left) << 160) |
            (uint256(right) << 208);
        return CollectionKey.wrap(bytes32(data));
    }
}
