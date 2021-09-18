//SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.3;

import "hardhat/console.sol";

import "@openzeppelin/contracts/utils/Arrays.sol";

import "./lib/ArrayUtils.sol";
import "./lib/proxy/AuthenticatedProxy.sol";

contract StaticValidators {
    string public constant name = "Flair Static Validators";

    constructor() public {}

    /**
     * Useful for offers that allow buyers provide how much they want to fill
     * (e.g. buyers can choose how many punks to mint on each investment).
     *
     * This static check assumes position of chosen amount (must be uint256) is predictable from the call data.
     * (e.g. PunksContract.mint(bytes32 punkType, uint256 amountToMint) -> offset must be "33"
     */
    function acceptContractAndSelectorAddUint256FillFromCallData(
        bytes memory extraData,
        address[5] memory addresses, // offer.beneficiary, offer.registry, offer.creator, offer.target, taker
        AuthenticatedProxy.HowToCall howToCall,
        uint256[5] memory uints, // msg.value, offer.maximumFill, offer.listingTime, offer.expirationTime, currentFill
        bytes memory data
    ) public pure returns (uint256) {
        (address requiredTarget, bytes4 requiredSelector, uint32 amountOffset) =
            abi.decode(extraData, (address, bytes4, uint32));

        require(howToCall == AuthenticatedProxy.HowToCall.Call, "STATIC_VALIDATOR/INVALID_CALLTYPE");
        require(requiredTarget == addresses[3], "STATIC_VALIDATOR/INVALID_TARGET");

        bytes memory requestedSelector = ArrayUtils.slice(data, 0, 4);

        require(
            ArrayUtils.arrayEq(requestedSelector, abi.encodePacked(requiredSelector)),
            "STATIC_VALIDATOR/INVALID_SELECTOR"
        );

        uint256 requestedAmount = abi.decode(ArrayUtils.slice(data, amountOffset, 32), (uint256));
        uint256 newFill = uints[4] + requestedAmount; /* currentFill */

        require(
            newFill <= uints[1], /* maximumFill */
            "STATIC_VALIDATOR/EXCEEDS_MAX_FILL"
        );

        return newFill;
    }

    function acceptContractAndSelectorAddUint32FillFromCallData(
        bytes memory extraData,
        address[5] memory addresses, // offer.beneficiary, offer.registry, offer.creator, offer.target, taker
        AuthenticatedProxy.HowToCall howToCall,
        uint256[5] memory uints, // msg.value, offer.maximumFill, offer.listingTime, offer.expirationTime, currentFill
        bytes memory data
    ) public pure returns (uint256) {
        (address requiredTarget, bytes4 requiredSelector, uint32 amountOffset) =
            abi.decode(extraData, (address, bytes4, uint32));

        require(howToCall == AuthenticatedProxy.HowToCall.Call, "STATIC_VALIDATOR/INVALID_CALLTYPE");
        require(requiredTarget == addresses[3], "STATIC_VALIDATOR/INVALID_TARGET");

        bytes memory requestedSelector = ArrayUtils.slice(data, 0, 4);

        require(
            ArrayUtils.arrayEq(requestedSelector, abi.encodePacked(requiredSelector)),
            "STATIC_VALIDATOR/INVALID_SELECTOR"
        );

        uint32 requestedAmount = abi.decode(ArrayUtils.slice(data, amountOffset, 4), (uint32));
        uint256 newFill = uints[4] + requestedAmount; /* currentFill */

        require(
            newFill <= uints[1], /* maximumFill */
            "STATIC_VALIDATOR/EXCEEDS_MAX_FILL"
        );

        return newFill;
    }

    /**
     * Useful for offers that give buyers same amount of fill (e.g. all buyers get 2 punks for each investment).
     */
    function acceptContractAndSelectorAddUint32FillFromExtraData(
        bytes memory extraData,
        address[5] memory addresses, // offer.beneficiary, offer.registry, offer.creator, offer.target, taker
        AuthenticatedProxy.HowToCall howToCall,
        uint256[5] memory uints, // msg.value, offer.maximumFill, offer.listingTime, offer.expirationTime, currentFill
        bytes memory data
    ) public pure returns (uint256) {
        (address requiredTarget, bytes4 requiredSelector, uint32 offeredAmount) =
            abi.decode(extraData, (address, bytes4, uint32));

        require(howToCall == AuthenticatedProxy.HowToCall.Call, "STATIC_VALIDATOR/INVALID_CALLTYPE");
        require(requiredTarget == addresses[3], "STATIC_VALIDATOR/INVALID_TARGET");

        bytes memory requestedSelector = ArrayUtils.slice(data, 0, 4);

        require(
            ArrayUtils.arrayEq(requestedSelector, abi.encodePacked(requiredSelector)),
            "STATIC_VALIDATOR/INVALID_SELECTOR"
        );

        uint256 newFill = uints[4] + offeredAmount; /* currentFill */

        require(
            newFill <= uints[1], /* maximumFill */
            "STATIC_VALIDATOR/EXCEEDS_MAX_FILL"
        );

        return newFill;
    }

    function acceptTransferERC721Exact(
        bytes memory extraData,
        address[5] memory addresses, // offer.beneficiary, offer.registry, offer.creator, offer.target, taker
        AuthenticatedProxy.HowToCall howToCall,
        uint256[5] memory uints, // msg.value, offer.maximumFill, offer.listingTime, offer.expirationTime, currentFill
        bytes memory data
    ) public pure returns (uint256) {
        // Decode extradata
        (address tokenAddress, uint256 tokenId) = abi.decode(extraData, (address, uint256));

        require(
            uints[4] == 0, /* currentFill */
            "STATIC_VALIDATOR/ALREADY_FILLED"
        );

        // Call target == ERC-721 token to give
        require(
            addresses[3] == tokenAddress /* offer.target */
        );

        // Call type = call
        require(howToCall == AuthenticatedProxy.HowToCall.Call);

        // Assert calldata
        require(
            ArrayUtils.arrayEq(
                data,
                abi.encodeWithSignature(
                    "transferFrom(address,address,uint256)",
                    addresses[2], /* creator */
                    addresses[4], /* funder */
                    tokenId
                )
            )
        );

        return 1;
    }

    function acceptReturnERC721Exact(
        bytes memory extraData,
        address[5] memory addresses, // offer.beneficiary, offer.registry, offer.creator, offer.target, taker
        AuthenticatedProxy.HowToCall howToCall,
        uint256[5] memory uints, // msg.value, offer.maximumFill, offer.listingTime, offer.expirationTime, currentFill
        bytes memory data
    ) public pure returns (uint256) {
        // Decode extradata
        (address tokenAddress, uint256 expectedTokenId) = abi.decode(extraData, (address, uint256));

        require(
            uints[4] > 0, /* currentFill */
            "STATIC_VALIDATOR/NOT_FILLED"
        );

        // Call target == ERC-721 token to give
        require(
            addresses[3] == tokenAddress /* offer.target */
        );

        // Call type = call
        require(howToCall == AuthenticatedProxy.HowToCall.Call);

        // Assert calldata
        require(
            ArrayUtils.arrayEq(
                data,
                abi.encodeWithSignature(
                    "transferFrom(address,address,uint256)",
                    addresses[4], /* funder */
                    addresses[2], /* creator */
                    expectedTokenId
                )
            )
        );

        return 0;
    }

    function acceptReturnERC721Any(
        bytes memory extraData,
        address[5] memory addresses, // offer.beneficiary, offer.registry, offer.creator, offer.target, taker
        AuthenticatedProxy.HowToCall howToCall,
        uint256[5] memory uints, // msg.value, offer.maximumFill, offer.listingTime, offer.expirationTime, currentFill
        bytes memory data
    ) public pure returns (uint256) {
        // Decode extradata
        (address token) = abi.decode(extraData, (address));

        require(
            uints[4] > 0, /* currentFill */
            "STATIC_VALIDATOR/NOT_FILLED"
        );

        // Call target == ERC-721 token to give
        require(
            addresses[3] == token /* offer.target */
        );

        // Call type = call
        require(howToCall == AuthenticatedProxy.HowToCall.Call);

        // Assert calldata

        uint256 tokenId = getNftTokenIdFromCalldata(data);
        require(tokenId > 0, "STATIC_VALIDATOR/INVALID_TOKEN_ID");

        require(
            ArrayUtils.arrayEq(
                data,
                abi.encodeWithSignature(
                    "transferFrom(address,address,uint256)",
                    addresses[4], /* taker */
                    addresses[2], /* creator */
                    tokenId
                )
            )
        );

        return 0;
    }

    function acceptReturnERC721Bulk(
        bytes memory extraData,
        address[5] memory addresses, // offer.beneficiary, offer.registry, offer.creator, offer.target, taker
        AuthenticatedProxy.HowToCall howToCall,
        uint256[5] memory uints, // msg.value, offer.maximumFill, offer.listingTime, offer.expirationTime, currentFill
        bytes memory data
    ) public pure returns (uint256) {
        // Decode extradata
        (address token) = abi.decode(extraData, (address));

        require(
            uints[4] > 0, /* currentFill */
            "STATIC_VALIDATOR/NOT_FILLED"
        );

        // Call target == ERC-721 token to give
        require(
            addresses[3] == token /* offer.target */
        );

        // Call type = call
        require(howToCall == AuthenticatedProxy.HowToCall.Call);

        // Assert calldata

        uint256[] memory tokenIds = getNftTokenIdsFromCalldata(data);
        require(tokenIds.length > 0, "STATIC_VALIDATOR/INVALID_TOKEN_ID");

        require(
            ArrayUtils.arrayEq(
                data,
                abi.encodeWithSignature(
                    "transferFromBulk(address,address,uint256[])",
                    addresses[4], /* taker */
                    addresses[2], /* creator */
                    tokenIds
                )
            )
        );

        uint256 newFill = uints[4] /* currentFill */ - tokenIds.length;

        return newFill;
    }

    function acceptTransferERC1155AnyAmount(
        bytes memory extraData,
        address[5] memory addresses, // offer.beneficiary, offer.registry, offer.creator, offer.target, taker
        AuthenticatedProxy.HowToCall howToCall,
        uint256[5] memory uints, // msg.value, offer.maximumFill, offer.listingTime, offer.expirationTime, currentFill
        bytes memory data
    ) public pure returns (uint256) {
        // Decode extradata
        (address tokenAddress, uint256 tokenId) = abi.decode(extraData, (address, uint256));

        require(
            uints[1] > uints[4], /* maximumFill */ /* currentFill */
            "STATIC_VALIDATOR/ALREADY_FILLED"
        );
        uint256 remainingFill = uints[1] - uints[4]; /* maximumFill */ /* currentFill */

        // Call target == ERC-1155 token to give
        require(
            addresses[3] == tokenAddress /* offer.target */
        );
        // Call type = call
        require(howToCall == AuthenticatedProxy.HowToCall.Call);

        uint256 requestedAmount = getERC1155AmountFromCalldata(data);
        require(remainingFill >= requestedAmount, "STATIC_VALIDATOR/EXCEEDS_MAXIMUM_FILL");

        // Assert calldata
        require(
            ArrayUtils.arrayEq(
                data,
                abi.encodeWithSignature(
                    "safeTransferFrom(address,address,uint256,uint256,bytes)",
                    addresses[2], /* creator */
                    addresses[4], /* taker */
                    tokenId,
                    requestedAmount,
                    ""
                )
            )
        );

        uint256 newFill = uints[4] + requestedAmount; /* currentFill */

        require(
            newFill <= uints[1], /* maximumFill */
            "STATIC_VALIDATOR/EXCEEDS_MAX_FILL"
        );

        return newFill;
    }

    function acceptReturnERC1155AnyAmount(
        bytes memory extraData,
        address[5] memory addresses, // offer.beneficiary, offer.registry, offer.creator, offer.target, taker
        AuthenticatedProxy.HowToCall howToCall,
        uint256[5] memory uints, // msg.value, offer.maximumFill, offer.listingTime, offer.expirationTime, currentFill
        bytes memory data
    ) public pure returns (uint256) {
        // Decode extradata
        (address token, uint256 tokenId) = abi.decode(extraData, (address, uint256));

        require(
            uints[4] /* currentFill */ > 0,
            "STATIC_VALIDATOR/NOT_FILLED"
        );

        // Call target == ERC-1155 token to give
        require(
            addresses[3] /* offer.target */ == token
        );

        // Call type = call
        require(howToCall == AuthenticatedProxy.HowToCall.Call);

        uint256 requestedAmount = getERC1155AmountFromCalldata(data);
        require(uints[4] /* currentFill */ >= requestedAmount, "STATIC_VALIDATOR/EXCEEDS_CURRENT_FILL");

        // Assert calldata

        require(
            ArrayUtils.arrayEq(
                data,
                abi.encodeWithSignature(
                    "safeTransferFrom(address,address,uint256,uint256,bytes)",
                    addresses[4], /* taker */
                    addresses[2], /* creator */
                    tokenId,
                    requestedAmount,
                    ""
                )
            )
        );

        return uints[4] /* currentFill */ - requestedAmount;
    }

    function getERC1155AmountFromCalldata(bytes memory data) internal pure returns (uint256 amount) {
        amount = abi.decode(ArrayUtils.slice(data, 100, 32), (uint256));
    }

    function getNftTokenIdFromCalldata(bytes memory data) internal pure returns (uint256 tokenId) {
        tokenId = abi.decode(ArrayUtils.slice(data, 68, 32), (uint256));
    }

    function getNftTokenIdsFromCalldata(bytes memory data) internal pure returns (uint256[] memory tokenIds) {
        tokenIds = abi.decode(ArrayUtils.slice(data, 68, data.length - 68), (uint256[]));
    }
}
