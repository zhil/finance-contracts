//SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.3;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "./lib/BancorFormula.sol";
import "./lib/ERC712.sol";
import "./Offers.sol";

import "hardhat/console.sol";

contract Flair is Offers, BancorFormula, AccessControlUpgradeable {
    using AddressUpgradeable for address;
    using AddressUpgradeable for address payable;

    string public constant name = "Flair.Finance";

    string public constant version = "0.1";

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    uint256 constant INVERSE_BASIS_POINT = 10000;

    address internal _treasury;

    address internal _funding;

    uint256 internal _protocolFee;

    /* Offer total paid funding costs, by maker address then by hash. */
    mapping(address => mapping(bytes32 => uint256)) public offerFundings;

    /* EVENTS */

    event OfferFunded(
        bytes32 hash,
        address indexed maker,
        address indexed operator,
        uint256 filledAmount,
        uint256 newFill
    );

    function initialize(
        address[] memory registryAddrs,
        address treasury,
        address funding,
        uint256 protocolFee
    ) public initializer {
        __Offer_init(name, version);

        _treasury = treasury;
        _funding = funding;
        _protocolFee = protocolFee;

        for (uint256 ind = 0; ind < registryAddrs.length; ind++) {
            registries[registryAddrs[ind]] = true;
        }
    }

    /* MODIFIERS */

    modifier isGovernor() {
        require(hasRole(GOVERNOR_ROLE, _msgSender()), "FLAIR_FINANCE/NOT_GOVERNOR");
        _;
    }

    /* ADMIN */

    function setProtocolFee(uint256 newValue) public isGovernor() {
        _protocolFee = newValue;
    }

    function setTreasury(address newAddress) public isGovernor() {
        _treasury = newAddress;
    }

    function setFunding(address newAddress) public isGovernor() {
        _funding = newAddress;
    }

    /* PUBLIC */

    function hashOffer(
        address beneficiary,
        uint256[8] calldata fundingOptions,
        address registry,
        address maker,
        address staticTarget,
        bytes4 staticSelector,
        bytes calldata staticExtradata,
        uint256 maximumFill,
        uint256 listingTime,
        uint256 expirationTime,
        uint256 salt
    ) external pure returns (bytes32 hash) {
        return
            _hashOffer(
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
                )
            );
    }

    function hashToSign(bytes32 orderHash) external view returns (bytes32 hash) {
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
        uint256 maximumFill,
        uint256 listingTime,
        uint256 expirationTime,
        uint256 salt
    ) external view returns (bool) {
        Offer memory offer =
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
            );
        return _validateOfferParameters(offer, _hashOffer(offer));
    }

    function validateOfferAuthorization(
        bytes32 hash,
        address maker,
        bytes calldata signature
    ) external view returns (bool) {
        return _validateOfferAuthorization(hash, maker, signature);
    }

    function approveOfferHash(bytes32 hash) external {
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
        uint256 maximumFill,
        uint256 listingTime,
        uint256 expirationTime,
        uint256 salt
    ) external {
        return
            _approveOffer(
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
                )
            );
    }

    function setOfferFill(bytes32 hash, uint256 fill) external {
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
            _msgSender(),
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
                uints[3] // salt
            ),
            Call(
                addrs[4], // target
                howToCall,
                data
            ),
            signature
        );
    }

    function getOfferFundingCost(
        address maker,
        bytes32 hash,
        uint256[8] calldata fundingOptions,
        uint256 fillAmount
    ) public view returns (uint256 fundingCost, uint256 protocolFeeAmount) {
        fundingCost = BancorFormula._fundCost(
            fundingOptions[5] + fills[maker][hash],
            fundingOptions[6] + offerFundings[maker][hash],
            uint32(fundingOptions[7]),
            fillAmount
        );

        protocolFeeAmount = (fundingCost * _protocolFee) / INVERSE_BASIS_POINT;
    }

    /* INTERNAL */

    function _fundOffer(
        address taker,
        Offer memory offer,
        Call memory call,
        bytes memory signature
    ) internal {
        (bytes32 hash, uint256 previousFill, uint256 newFill) = _executeOffer(offer, call, signature);

        uint256 filled = newFill - previousFill;

        require(filled > 0, "FLAIR_FINANCE/UNFILLED");

        uint256 fundingCost =
            BancorFormula._fundCost(
                offer.fundingOptions[5] + previousFill,
                offer.fundingOptions[6] + offerFundings[offer.maker][hash],
                uint32(offer.fundingOptions[7]),
                filled
            );

        offerFundings[offer.maker][hash] += fundingCost;

        {
            uint256 protocolFeeAmount = (fundingCost * _protocolFee) / INVERSE_BASIS_POINT;

            require(msg.value == fundingCost + protocolFeeAmount, "FLAIR_FINANCE/INVALID_PAYMENT");

            payable(address(_treasury)).sendValue(protocolFeeAmount);
        }

        (bool success, ) =
            _funding.call{value: fundingCost}(
                abi.encodeWithSignature(
                    "registerInvestment(address,uint256,bytes32,uint256,address,uint256[8])",
                    taker
                    filled,
                    hash,
                    fundingCost,
                    offer.beneficiary,
                    offer.fundingOptions
                )
            );

        require(success, "FLAIR_FINANCE/INVESTMENT_FAILED");

        emit OfferFunded(hash, offer.maker, msg.sender, filled, newFill);
    }
}
