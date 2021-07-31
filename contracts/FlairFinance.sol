//SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.5;

import "./Offers.sol";
import "./Funding.sol";
import "./lib/BancorFormula.sol";

contract FlairFinance is Offers, Funding, BancorFormula {
    function hashOffer(
        address beneficiary,
        uint256[9] memory fundingOptions,
        address registry,
        address maker,
        address staticTarget,
        bytes4 staticSelector,
        bytes calldata staticExtradata,
        uint maximumFill,
        uint listingTime,
        uint expirationTime,
        uint salt
    )
    external
    pure
    returns (bytes32 hash)
    {
        return _hashOffer(Offer(
            beneficiary,
            fundingOptions,
            registry,
            maker,
            staticTarget,
            staticSelector,
            staticExtradata,
            maximumFill,
            listingTime,
            expirationTime,
            salt
        ));
    }

    function hashToSign(bytes32 orderHash)
    external
    view
    returns (bytes32 hash)
    {
        return _hashToSign(orderHash);
    }

    function validateOfferParameters(
        address beneficiary,
        uint256[9] memory fundingOptions,
        address registry,
        address maker,
        address staticTarget,
        bytes4 staticSelector,
        bytes calldata staticExtradata,
        uint maximumFill,
        uint listingTime,
        uint expirationTime,
        uint salt
    )
    external
    view
    returns (bool)
    {
        Offer memory offer = Offer(
            beneficiary,
            fundingOptions,
            registry,
            maker,
            staticTarget,
            staticSelector,
            staticExtradata,
            maximumFill,
            listingTime,
            expirationTime,
            salt
        );
        return validateOfferParameters(offer, hashOffer(offer));
    }

    function validateOfferAuthorization(bytes32 hash, address maker, bytes calldata signature)
    external
    view
    returns (bool)
    {
        return _validateOfferAuthorization(hash, maker, signature);
    }

    function approveOfferHash(bytes32 hash)
    external
    {
        return _approveOfferHash(hash);
    }

    function approveOffer(
        address beneficiary,
        uint256[9] memory fundingOptions,
        address registry,
        address maker,
        address staticTarget,
        bytes4 staticSelector,
        bytes calldata staticExtradata,
        uint maximumFill,
        uint listingTime,
        uint expirationTime,
        uint salt
    )
    external
    {
        return _approveOffer(Offer(
            beneficiary,
            fundingOptions,
            registry,
            maker,
            staticTarget,
            staticSelector,
            staticExtradata,
            maximumFill,
            listingTime,
            expirationTime,
            salt
        ));
    }

    function setOfferFill(bytes32 hash, uint fill)
    external
    {
        return _setOfferFill(hash, fill);
    }

    function fundOffer(
        // Offer
        address beneficiary,
        uint256[9] memory fundingOptions,
        address registry,
        address maker,
        address staticTarget,
        bytes4 staticSelector,
        bytes staticExtradata,
        uint maximumFill,
        uint listingTime,
        uint expirationTime,
        uint salt,
        bytes signature,
        // Call
        address target,
        AuthenticatedProxy.HowToCall howToCall,
        bytes data
    ) public payable {
        uint256 (previousFill, newFill) = _executeOffer(
            Offer(
                beneficiary,
                fundingOptions,
                registry,
                maker,
                staticTarget,
                staticSelector,
                staticExtradata,
                maximumFill,
                listingTime,
                expirationTime,
                salt
            ),
            Call(
                target,
                howToCall,
                data
            ),
            signature
        );

        require(previousFill < newFill, "FINANCE/UNFILLED");

        uint256 requiredPayment = calculateFundingCost(previousFill, newFill, fundingOptions);

        _registerInvestment(
            requiredPayment,
            beneficiary,
            fundingOptions
        );
    }

    function calculateFundingCost(uint256 previousFill, uint256 newFill, uint256[9] memory fundingOptions) internal pure returns (uint256) {
        return fundCost(fundingOptions[3], fundingOptions[4], fundingOptions[5], previousFill - newFill);
    }
}
