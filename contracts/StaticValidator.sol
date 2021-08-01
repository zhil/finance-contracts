//SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.3;

import "@openzeppelin/contracts/utils/Arrays.sol";

import "./lib/ArrayUtils.sol";
import "./lib/proxy/AuthenticatedProxy.sol";

contract StaticValidator {
    string public constant name = "Flair.Finance Static Validators";

    constructor ()
    public
    {}

    /**
     * Useful for offers that allow buyers provide how much they want to fill
     * (e.g. buyers can choose how many punks to mint on each investment).
     *
     * This static check assumes position of chosen amount (must be uin256) is predictable from the call data.
     * (e.g. PunksContract.mint(bytes32 punkType, uint256 amountToMint) -> offset must be "33"
     */
    function acceptContractAndSelectorAddUint256FillFromCallData(
        bytes memory extraData,
        address[5] memory addresses, // offer.beneficiary, offer.registry, offer.maker, offer.target, taker
        AuthenticatedProxy.HowToCall howToCall,
        uint[5] memory uints, // msg.value, offer.maximumFill, offer.listingTime, offer.expirationTime, currentFill
        bytes memory data
    )
    public
    pure
    returns (uint256)
    {
        (address requiredTarget, bytes32 requiredSelector, uint32 amountOffset) = abi.decode(extraData, (address, bytes32, uint32));

        require(requiredTarget == addresses[3], "STATIC_VALIDATOR/INVALID_TARGET");

        (bytes32 requestedSelector) = abi.decode(ArrayUtils.arraySlice(data, 0, 32),(bytes32));

        require(requestedSelector == requiredSelector, "STATIC_VALIDATOR/INVALID_SELECTOR");

        (uint256 requestedAmount) = abi.decode(ArrayUtils.arraySlice(data, amountOffset, 32),(uint256));
        uint256 newFill = uints[4]/* currentFill */ + requestedAmount;

        require(newFill <= uints[1]/* maximumFill */, "STATIC_VALIDATOR/EXCEEDS_MAX_FILL");

        return newFill;
    }

    function acceptContractAndSelectorAddUint32FillFromCallData(
        bytes memory extraData,
        address[5] memory addresses, // offer.beneficiary, offer.registry, offer.maker, offer.target, taker
        AuthenticatedProxy.HowToCall howToCall,
        uint[5] memory uints, // msg.value, offer.maximumFill, offer.listingTime, offer.expirationTime, currentFill
        bytes memory data
    )
    public
    pure
    returns (uint256)
    {
        (address requiredTarget, bytes32 requiredSelector, uint32 amountOffset) = abi.decode(extraData, (address, bytes32, uint32));

        require(requiredTarget == addresses[3], "STATIC_VALIDATOR/INVALID_TARGET");

        (bytes32 requestedSelector) = abi.decode(ArrayUtils.arraySlice(data, 0, 32),(bytes32));

        require(requestedSelector == requiredSelector, "STATIC_VALIDATOR/INVALID_SELECTOR");

        (uint32 requestedAmount) = abi.decode(ArrayUtils.arraySlice(data, amountOffset, 4),(uint32));
        uint256 newFill = uints[4]/* currentFill */ + requestedAmount;

        require(newFill <= uints[1]/* maximumFill */, "STATIC_VALIDATOR/EXCEEDS_MAX_FILL");

        return newFill;
    }

    /**
     * Useful for offers that give buyers same amount of fill (e.g. all buyers get 2 punks for each investment).
     */
    function acceptContractAndSelectorAddUint32FillFromExtraData(
        bytes memory extraData,
        address[5] memory addresses, // offer.beneficiary, offer.registry, offer.maker, offer.target, taker
        AuthenticatedProxy.HowToCall howToCall,
        uint[5] memory uints, // msg.value, offer.maximumFill, offer.listingTime, offer.expirationTime, currentFill
        bytes memory data
    )
    public
    pure
    returns (uint256)
    {
        (address requiredTarget, bytes32 requiredSelector, uint32 offeredAmount) = abi.decode(extraData, (address, bytes32, uint32));

        require(requiredTarget == addresses[3], "STATIC_VALIDATOR/INVALID_TARGET");

        (bytes32 requestedSelector) = abi.decode(ArrayUtils.arraySlice(data, 0, 32),(bytes32));

        require(requestedSelector == requiredSelector , "STATIC_VALIDATOR/INVALID_SELECTOR");

        uint256 newFill = uints[4]/* currentFill */ + offeredAmount;

        require(newFill <= uints[1]/* maximumFill */, "STATIC_VALIDATOR/EXCEEDS_MAX_FILL");

        return newFill;
    }

    function acceptTransferERC721Exact(
        bytes memory extraData,
        address[5] memory addresses, // offer.beneficiary, offer.registry, offer.maker, offer.target, taker
        AuthenticatedProxy.HowToCall howToCall,
        uint[5] memory uints, // msg.value, offer.maximumFill, offer.listingTime, offer.expirationTime, currentFill
        bytes memory data
    )
    public
    pure
    returns (uint256)
    {
        // Decode extradata
        (address token, uint tokenId) = abi.decode(extraData, (address, uint));

        require(uints[4]/* currentFill */ == 0, "STATIC_VALIDATOR/ALREADY_FILLED");

        // Call target == ERC-721 token to give
        require(addresses[3]/* offer.target */ == token);
        // Call type = call
        require(howToCall == AuthenticatedProxy.HowToCall.Call);
        // Assert calldata
        require(ArrayUtils.arrayEq(
            data,
            abi.encodeWithSignature("transferFrom(address,address,uint256)",
            addresses[2]/* maker */, addresses[4]/* taker */, tokenId
        )));

        return 1;
    }

    function acceptTransferERC1155AnyAmount(
        bytes memory extraData,
        address[5] memory addresses, // offer.beneficiary, offer.registry, offer.maker, offer.target, taker
        AuthenticatedProxy.HowToCall howToCall,
        uint[5] memory uints, // msg.value, offer.maximumFill, offer.listingTime, offer.expirationTime, currentFill
        bytes memory data
    )
        public
        pure
        returns (uint256)
    {
        // Decode extradata
        (address token, uint256 tokenId) = abi.decode(extraData, (address, uint256));

        require(uints[2]/* maximumFill */ > uints[4]/* currentFill */, "STATIC_VALIDATOR/ALREADY_FILLED");
        uint256 remainingFill = uints[2]/* maximumFill */ - uints[4]/* currentFill */;

        // Call target == ERC-1155 token to give
        require(addresses[3]/* offer.target */ == token);
        // Call type = call
        require(howToCall == AuthenticatedProxy.HowToCall.Call);

        uint256 requestedAmount = getERC1155AmountFromCalldata(data);
        require(remainingFill >= requestedAmount, "STATIC_VALIDATOR/EXCEEDS_MAXIMUM_FILL");

        // Assert calldata
        require(ArrayUtils.arrayEq(
            data,
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256,uint256,bytes)",
                addresses[2]/* maker */, addresses[4]/* taker */, tokenId, requestedAmount, ""
            )
        ));

        uint256 newFill = uints[4]/* currentFill */ + requestedAmount;

        require(newFill <= uints[1]/* maximumFill */, "STATIC_VALIDATOR/EXCEEDS_MAX_FILL");

        return newFill;
    }

	function getERC1155AmountFromCalldata(bytes memory data)
		internal
		pure
		returns (uint256)
	{
		(uint256 amount) = abi.decode(ArrayUtils.arraySlice(data, 100, 32),(uint256));
		return amount;
	}
}
