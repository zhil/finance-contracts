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
    mapping(address => mapping(bytes32 => uint256)) public offerTotalFunded;

    /* EVENTS */

    event OfferFunded(
        bytes32 hash,
        address indexed maker,
        address indexed operator,
        uint256 filledAmount,
        uint256 newFill
    );

    event FundingCancelled(
        bytes32 hash,
        address indexed maker,
        address indexed operator,
        uint256 unfilledAmount,
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
        uint256[8] calldata fundingOptions,
        address[6] calldata addrs,
        uint256[3] calldata uints,
        bytes4[2] memory validatorSelectors,
        bytes calldata fundingValidatorExtradata,
        bytes calldata cancellationValidatorExtradata
    ) external pure returns (bytes32 hash) {
        return
            _hashOffer(
                Offer(
                    addrs[0], // beneficiary
                    fundingOptions,
                    addrs[1], // registry
                    addrs[2], // maker
                    addrs[3], // fundingValidatorTarget
                    validatorSelectors[0], // fundingValidatorSelector
                    fundingValidatorExtradata,
                    addrs[4], // cancellationValidatorTarget
                    validatorSelectors[1], // cancellationValidatorSelector
                    cancellationValidatorExtradata,
                    uints[0], // maximumFill
                    uints[1], // listingTime
                    uints[2]  // expirationTime
                )
            );
    }

    function hashToSign(bytes32 orderHash) external view returns (bytes32 hash) {
        return _hashToSign(orderHash);
    }

    function validateOfferParameters(
        uint256[8] calldata fundingOptions,
        address[6] calldata addrs,
        uint256[3] calldata uints,
        bytes4[2] memory validatorSelectors,
        bytes calldata fundingValidatorExtradata,
        bytes calldata cancellationValidatorExtradata
    ) external view returns (bool) {
        Offer memory offer =
            Offer(
                addrs[0], // beneficiary
                fundingOptions,
                addrs[1], // registry
                addrs[2], // maker
                addrs[3], // fundingValidatorTarget
                validatorSelectors[0], // fundingValidatorSelector
                fundingValidatorExtradata,
                addrs[4], // cancellationValidatorTarget
                validatorSelectors[1], // cancellationValidatorSelector
                cancellationValidatorExtradata,
                uints[0], // maximumFill
                uints[1], // listingTime
                uints[2]  // expirationTime
            );
        return _validateOfferFundingParameters(offer, _hashOffer(offer));
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
        uint256[8] calldata fundingOptions,
        address[6] calldata addrs,
        uint256[3] calldata uints,
        bytes4[2] memory validatorSelectors,
        bytes calldata fundingValidatorExtradata,
        bytes calldata cancellationValidatorExtradata
    ) external {
        return
            _approveOffer(
                Offer(
                    addrs[0], // beneficiary
                    fundingOptions,
                    addrs[1], // registry
                    addrs[2], // maker
                    addrs[3], // fundingValidatorTarget
                    validatorSelectors[0], // fundingValidatorSelector
                    fundingValidatorExtradata,
                    addrs[4], // cancellationValidatorTarget
                    validatorSelectors[1], // cancellationValidatorSelector
                    cancellationValidatorExtradata,
                    uints[0], // maximumFill
                    uints[1], // listingTime
                    uints[2]  // expirationTime
                )
            );
    }

    function setOfferFill(bytes32 hash, uint256 fill) external {
        return _setOfferFill(hash, fill);
    }

    function fundOffer(
        uint256[8] calldata fundingOptions,
        address[6] calldata addrs,
        uint256[3] calldata uints,
        bytes4[2] memory validatorSelectors,
        bytes calldata fundingValidatorExtradata,
        bytes calldata cancellationValidatorExtradata,
        bytes memory signature,
        AuthenticatedProxy.HowToCall howToCall,
        bytes calldata data
    ) public payable {
        _fundOffer(
            Offer(
                addrs[0], // beneficiary
                fundingOptions,
                addrs[1], // registry
                addrs[2], // maker
                addrs[3], // fundingValidatorTarget
                validatorSelectors[0], // fundingValidatorSelector
                fundingValidatorExtradata,
                addrs[4], // cancellationValidatorTarget
                validatorSelectors[1], // cancellationValidatorSelector
                cancellationValidatorExtradata,
                uints[0], // maximumFill
                uints[1], // listingTime
                uints[2]  // expirationTime
            ),
            Call(
                addrs[5], // target
                howToCall,
                data
            ),
            signature
        );
    }

    function cancelFunding(
        uint256[8] calldata fundingOptions,
        address[6] calldata addrs,
        uint256[4] calldata uints,
        bytes4[2] memory validatorSelectors,
        bytes calldata fundingValidatorExtradata,
        bytes calldata cancellationValidatorExtradata,
        bytes memory signature,
        AuthenticatedProxy.HowToCall howToCall,
        bytes calldata data
    ) public {
        _cancelFunding(
            Offer(
                addrs[0], // beneficiary
                fundingOptions,
                addrs[1], // registry
                addrs[2], // maker
                addrs[3], // fundingValidatorTarget
                validatorSelectors[0], // fundingValidatorSelector
                fundingValidatorExtradata,
                addrs[4], // cancellationValidatorTarget
                validatorSelectors[1], // cancellationValidatorSelector
                cancellationValidatorExtradata,
                uints[0], // maximumFill
                uints[1], // listingTime
                uints[2]  // expirationTime
            ),
            Call(
                addrs[5], // target
                howToCall,
                data
            ),
            signature,
            uints[3] // contributionId
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
            fundingOptions[6] + offerTotalFunded[maker][hash],
            uint32(fundingOptions[7]),
            fillAmount
        );

        protocolFeeAmount = (fundingCost * _protocolFee) / INVERSE_BASIS_POINT;
    }

    /* INTERNAL */

    function _fundOffer(
        Offer memory offer,
        Call memory call,
        bytes memory signature
    ) internal {
        address taker = _msgSender();
        (bytes32 hash, uint256 previousFill, uint256 newFill) = _executeOfferFunding(offer, call, signature);

        uint256 filled = newFill - previousFill;

        require(filled > 0, "FLAIR_FINANCE/UNFILLED");

        uint256 fundingCost =
            BancorFormula._fundCost(
                offer.fundingOptions[5] + previousFill,
                offer.fundingOptions[6] + offerTotalFunded[offer.maker][hash],
                uint32(offer.fundingOptions[7]),
                filled
            );

        offerTotalFunded[offer.maker][hash] += fundingCost;

        {
            uint256 protocolFeeAmount = (fundingCost * _protocolFee) / INVERSE_BASIS_POINT;

            require(msg.value == fundingCost + protocolFeeAmount, "FLAIR_FINANCE/INVALID_PAYMENT");

            payable(address(_treasury)).sendValue(protocolFeeAmount);
        }

        (bool success, ) =
            _funding.call{value: fundingCost}(
                abi.encodeWithSignature(
                    "registerContribution(address,bytes32,uint256[8],address,uint256,uint256)",
                    offer.beneficiary,
                    hash,
                    offer.fundingOptions,
                    taker,
                    filled,
                    fundingCost
                )
            );

        require(success, "FLAIR_FINANCE/INVESTMENT_FAILED");

        emit OfferFunded(hash, offer.maker, msg.sender, filled, newFill);
    }

    function _cancelFunding(
        Offer memory offer,
        Call memory call,
        bytes memory signature,
        uint256 contributionId
    ) internal {
        address taker = _msgSender();
        (bytes32 hash, uint256 previousFill, uint256 newFill) = _executeOfferCancellation(offer, call, signature);

        require(previousFill >= newFill, "FLAIR_FINANCE/NOT_UNFILLED");

        uint256 unfilled = previousFill - newFill;

        (bool success, ) =
            _funding.call(
                abi.encodeWithSignature(
                    "refundContribution(address,bytes32,address,uint256,uint256)",
                    offer.beneficiary,
                    hash,
                    taker,
                    unfilled,
                    contributionId
                )
            );

        require(success, "FLAIR_FINANCE/CANCELLATION_FAILED");

        emit FundingCancelled(hash, offer.maker, msg.sender, unfilled, newFill);
    }
}
