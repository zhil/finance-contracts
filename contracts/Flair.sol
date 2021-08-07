//SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.3;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "./lib/BancorFormula.sol";
import "./lib/ERC712.sol";
import "./Campaigns.sol";

import "hardhat/console.sol";

contract Flair is Campaigns, BancorFormula, AccessControlUpgradeable {
    using AddressUpgradeable for address;
    using AddressUpgradeable for address payable;

    string public constant name = "Flair.Finance";

    string public constant version = "0.1";

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    uint256 constant INVERSE_BASIS_POINT = 10000;

    address internal _treasury;

    address internal _funding;

    uint256 internal _protocolFee;

    /* Campaign total paid funding costs, by creator address then by hash. */
    mapping(address => mapping(bytes32 => uint256)) public campaignTotalFunded;

    /* EVENTS */

    event CampaignFunded(
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
        __Campaign_init(name, version);

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

    function hashCampaign(
        uint256[8] calldata fundingOptions,
        address[6] calldata addrs,
        uint256[3] calldata uints,
        bytes4[2] memory validatorSelectors,
        bytes calldata contributionValidatorExtradata,
        bytes calldata cancellationValidatorExtradata
    ) external pure returns (bytes32 hash) {
        return
            _hashCampaign(
                Campaign(
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

    function hashToSign(bytes32 orderHash) external view returns (bytes32 hash) {
        return _hashToSign(orderHash);
    }

    function validateCampaignParameters(
        uint256[8] calldata fundingOptions,
        address[6] calldata addrs,
        uint256[3] calldata uints,
        bytes4[2] memory validatorSelectors,
        bytes calldata contributionValidatorExtradata,
        bytes calldata cancellationValidatorExtradata
    ) external view returns (bool) {
        Campaign memory campaign =
            Campaign(
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
        return _validateCampaignFundingParameters(campaign, _hashCampaign(campaign));
    }

    function validateCampaignAuthorization(
        bytes32 hash,
        address creator,
        bytes calldata signature
    ) external view returns (bool) {
        return _validateCampaignAuthorization(hash, creator, signature);
    }

    function approveCampaignHash(bytes32 hash) external {
        return _approveCampaignHash(hash);
    }

    function approveCampaign(
        uint256[8] calldata fundingOptions,
        address[6] calldata addrs,
        uint256[3] calldata uints,
        bytes4[2] memory validatorSelectors,
        bytes calldata contributionValidatorExtradata,
        bytes calldata cancellationValidatorExtradata
    ) external {
        return
            _approveCampaign(
                Campaign(
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

    function setCampaignFill(bytes32 hash, uint256 fill) external {
        return _setCampaignFill(hash, fill);
    }

    function fundCampaign(
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
        _fundCampaign(
            Campaign(
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
            Campaign(
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

    function getCampaignFundingCost(
        address creator,
        bytes32 hash,
        uint256[8] calldata fundingOptions,
        uint256 fillAmount
    ) public view returns (uint256 fundingCost, uint256 protocolFeeAmount) {
        fundingCost = BancorFormula._fundCost(
            fundingOptions[5] + fills[creator][hash],
            fundingOptions[6] + campaignTotalFunded[creator][hash],
            uint32(fundingOptions[7]),
            fillAmount
        );

        protocolFeeAmount = (fundingCost * _protocolFee) / INVERSE_BASIS_POINT;
    }

    /* INTERNAL */

    function _fundCampaign(
        Campaign memory campaign,
        Call memory call,
        bytes memory signature
    ) internal {
        address taker = _msgSender();
        (bytes32 hash, uint256 previousFill, uint256 newFill) = _executeCampaignContribution(campaign, call, signature);

        uint256 filled = newFill - previousFill;

        require(filled > 0, "FLAIR_FINANCE/UNFILLED");

        uint256 fundingCost =
            BancorFormula._fundCost(
                campaign.fundingOptions[5] + previousFill,
                campaign.fundingOptions[6] + campaignTotalFunded[campaign.creator][hash],
                uint32(campaign.fundingOptions[7]),
                filled
            );

        campaignTotalFunded[campaign.creator][hash] += fundingCost;

        {
            uint256 protocolFeeAmount = (fundingCost * _protocolFee) / INVERSE_BASIS_POINT;

            require(msg.value == fundingCost + protocolFeeAmount, "FLAIR_FINANCE/INVALID_PAYMENT");

            payable(address(_treasury)).sendValue(protocolFeeAmount);
        }

        (bool success, ) =
            _funding.call{value: fundingCost}(
                abi.encodeWithSignature(
                    "registerContribution(address,bytes32,uint256[8],address,uint256,uint256)",
                    campaign.beneficiary,
                    hash,
                    campaign.fundingOptions,
                    taker,
                    filled,
                    fundingCost
                )
            );

        require(success, "FLAIR_FINANCE/INVESTMENT_FAILED");

        emit CampaignFunded(hash, campaign.creator, msg.sender, filled, newFill);
    }

    function _cancelFunding(
        Campaign memory campaign,
        Call memory call,
        bytes memory signature,
        uint256 contributionId
    ) internal {
        address taker = _msgSender();
        (bytes32 hash, uint256 previousFill, uint256 newFill) = _executeCampaignCancellation(campaign, call, signature);

        require(previousFill >= newFill, "FLAIR_FINANCE/NOT_UNFILLED");

        uint256 unfilled = previousFill - newFill;

        (bool success, ) =
            _funding.call(
                abi.encodeWithSignature(
                    "refundContribution(address,bytes32,address,uint256,uint256)",
                    campaign.beneficiary,
                    hash,
                    taker,
                    unfilled,
                    contributionId
                )
            );

        require(success, "FLAIR_FINANCE/CANCELLATION_FAILED");

        emit FundingCancelled(hash, campaign.creator, msg.sender, unfilled, newFill);
    }
}
