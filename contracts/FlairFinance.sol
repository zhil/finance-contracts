//SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.3;

import "./Offers.sol";
import "./Funding.sol";
import "./lib/BancorFormula.sol";
import "./lib/ERC712.sol";

contract FlairFinance is BancorFormula, Funding, Offers {
    string public constant name = "Flair Finance";

    string public constant version = "0.1";

    function initialize() public initializer {
        DOMAIN_SEPARATOR = hash(EIP712Domain({
            name              : name,
            version           : version,
            chainId           : block.chainid,
            verifyingContract : address(this)
        }));
        __Offer_init();
        __Funding_init();
        __BancorFormula_init();
    }

    function hashOffer(
        address beneficiary,
        uint256[8] calldata fundingOptions,
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
        uint256[8] calldata fundingOptions,
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
        return _validateOfferParameters(offer, _hashOffer(offer));
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
        uint256[8] calldata fundingOptions,
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
        uint256[8] calldata fundingOptions,
        address[5] calldata addrs,
        uint256[4] calldata uints,
        bytes4 staticSelector,
        bytes calldata staticExtradata,
        bytes calldata signature,
        AuthenticatedProxy.HowToCall howToCall,
        bytes calldata data
    ) public payable {
        _fundOffer(
            Offer(
                addrs[0], // beneficiary
                fundingOptions,
                addrs[1], // registry
                addrs[2], // maker
                addrs[3], // staticTarget
                staticSelector,
                staticExtradata,
                uints[0], // maximumFill
                uints[1], // listingTime
                uints[2], // expirationTime
                uints[3]  // salt
            ),
            Call(
                addrs[4], // target
                howToCall,
                data
            ),
            signature
        );
    }

    function _fundOffer(
        Offer memory offer,
        Call memory call,
        bytes memory signature
    ) internal {
        (bytes32 hash, uint256 previousFill, uint256 newFill) = _executeOffer(offer, call, signature);

        uint256 filled = previousFill - newFill;

        require(filled > 0, "FINANCE/UNFILLED");

        _registerInvestment(
            filled,
            hash,
            fundCost(offer.fundingOptions[5], offer.fundingOptions[6], uint32(offer.fundingOptions[7]), filled),
            offer.beneficiary,
            offer.fundingOptions
        );
    }
}
