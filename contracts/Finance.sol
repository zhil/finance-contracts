//SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.3;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "./lib/BancorFormula.sol";
import "./Offers.sol";
import "./IFunding.sol";

contract Finance is Offers, BancorFormula, AccessControlUpgradeable {
    using AddressUpgradeable for address;
    using AddressUpgradeable for address payable;

    string public constant name = "Flair Finance";

    string public constant version = "0.1";

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    uint256 constant INVERSE_BASIS_POINT = 10000;

    address internal _treasury;

    IFunding internal _funding;

    uint256 internal _protocolFee;

    /* Offer total paid funding costs, by creator address then by hash. */
    mapping(address => mapping(bytes32 => uint256)) public offerTotalFunded;

    /* EVENTS */

    event OfferFunded(
        bytes32 hash,
        address indexed creator,
        address indexed operator,
        uint256 filledAmount,
        uint256 newFill
    );

    event FundingCancelled(
        bytes32 hash,
        address indexed creator,
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
        _funding = IFunding(funding);
        _protocolFee = protocolFee;

        for (uint256 ind = 0; ind < registryAddrs.length; ind++) {
            registries[registryAddrs[ind]] = true;
        }

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(GOVERNOR_ROLE, _msgSender());
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
        _funding = IFunding(newAddress);
    }

    function updateRegistryAddress(address addr, bool isActive) public isGovernor() {
        registries[addr] = isActive;
    }

    /* PUBLIC */

    function getParameters()
    public
    view
    virtual
    returns (
        uint256 protocolFee
    )
    {
        return (_protocolFee);
    }

    function hashOffer(
        uint256[8] calldata fundingOptions,
        address[6] calldata addrs,
        uint256[3] calldata uints,
        bytes4[2] memory validatorSelectors,
        bytes calldata contributionValidatorExtradata,
        bytes calldata cancellationValidatorExtradata
    ) external pure returns (bytes32 hash) {
        return
            _hashOffer(
                Offer(
                    addrs[0], // beneficiary
                    fundingOptions,
                    addrs[1], // registry
                    addrs[2], // creator
                    addrs[3], // contributionValidatorTarget
                    validatorSelectors[0], // contributionValidatorSelector
                    contributionValidatorExtradata,
                    addrs[4], // cancellationValidatorTarget
                    validatorSelectors[1], // cancellationValidatorSelector
                    cancellationValidatorExtradata,
                    uints[0], // maximumFill
                    uints[1], // listingTime
                    uints[2]  // expirationTime
                )
            );
    }

    function hashToSign(bytes32 offerHash) external view returns (bytes32 hash) {
        return _hashToSign(offerHash);
    }

    function validateOfferParameters(
        uint256[8] calldata fundingOptions,
        address[6] calldata addrs,
        uint256[3] calldata uints,
        bytes4[2] memory validatorSelectors,
        bytes calldata contributionValidatorExtradata,
        bytes calldata cancellationValidatorExtradata
    ) external view returns (bool) {
        Offer memory offer =
            Offer(
                addrs[0], // beneficiary
                fundingOptions,
                addrs[1], // registry
                addrs[2], // creator
                addrs[3], // contributionValidatorTarget
                validatorSelectors[0], // contributionValidatorSelector
                contributionValidatorExtradata,
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
        address creator,
        bytes calldata signature
    ) external view returns (bool) {
        return _validateOfferAuthorization(hash, creator, signature);
    }

    function approveOfferHash(bytes32 hash) external {
        return _approveOfferHash(hash);
    }

    function approveOffer(
        uint256[8] calldata fundingOptions,
        address[6] calldata addrs,
        uint256[3] calldata uints,
        bytes4[2] memory validatorSelectors,
        bytes calldata contributionValidatorExtradata,
        bytes calldata cancellationValidatorExtradata
    ) external {
        return
            _approveOffer(
                Offer(
                    addrs[0], // beneficiary
                    fundingOptions,
                    addrs[1], // registry
                    addrs[2], // creator
                    addrs[3], // contributionValidatorTarget
                    validatorSelectors[0], // contributionValidatorSelector
                    contributionValidatorExtradata,
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
        bytes calldata contributionValidatorExtradata,
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
                addrs[2], // creator
                addrs[3], // contributionValidatorTarget
                validatorSelectors[0], // contributionValidatorSelector
                contributionValidatorExtradata,
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
        bytes calldata contributionValidatorExtradata,
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
                addrs[2], // creator
                addrs[3], // contributionValidatorTarget
                validatorSelectors[0], // contributionValidatorSelector
                contributionValidatorExtradata,
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
        address creator,
        bytes32 hash,
        uint256[8] calldata fundingOptions,
        uint256 fillAmount
    ) public view returns (uint256 fundingCost, uint256 protocolFeeAmount) {
        fundingCost = BancorFormula._fundCost(
            fundingOptions[5] + fills[creator][hash],
            fundingOptions[6] + offerTotalFunded[creator][hash],
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
        (bytes32 hash, uint256 previousFill, uint256 newFill) = _executeOfferContribution(offer, call, signature);

        require(newFill > previousFill, "FLAIR_FINANCE/NOT_FILLED");

        uint256 filled = newFill - previousFill;

        uint256 fundingCost =
            BancorFormula._fundCost(
                offer.fundingOptions[5] + previousFill,
                offer.fundingOptions[6] + offerTotalFunded[offer.creator][hash],
                uint32(offer.fundingOptions[7]),
                filled
            );

        offerTotalFunded[offer.creator][hash] += fundingCost;

        {
            uint256 protocolFeeAmount = (fundingCost * _protocolFee) / INVERSE_BASIS_POINT;

            require(msg.value == fundingCost + protocolFeeAmount, "FLAIR_FINANCE/INVALID_PAYMENT");

            payable(address(_treasury)).sendValue(protocolFeeAmount);
        }

        _funding.registerContribution{value: fundingCost}(
            offer.beneficiary,
            hash,
            offer.fundingOptions,
            taker,
            filled,
            fundingCost
        );

        emit OfferFunded(hash, offer.creator, msg.sender, filled, newFill);
    }

    function _cancelFunding(
        Offer memory offer,
        Call memory call,
        bytes memory signature,
        uint256 contributionId
    ) internal {
        address taker = _msgSender();

        (bytes32 hash, uint256 previousFill, uint256 newFill) = _executeOfferCancellation(offer, call, signature);

        require(previousFill > newFill, "FLAIR_FINANCE/NOT_UNFILLED");

        offerTotalFunded[offer.creator][hash] -= _funding.contributions(contributionId).amount;

        uint256 unfilled = previousFill - newFill;

        _funding.refundContribution(
            offer.beneficiary,
            hash,
            taker,
            unfilled,
            contributionId
        );

        emit FundingCancelled(hash, offer.creator, msg.sender, unfilled, newFill);
    }
}
