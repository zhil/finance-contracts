//SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.3;

import "hardhat/console.sol";

interface IFunding {
    struct Contribution {
        address investor;
        bytes32 offerHash;
        uint256 amount;
        uint256 filled;
        uint256 registeredAt;
        uint256 refundedAt;
    }

    function contributions(uint256) external returns (Contribution memory);

    function registerContribution(
        address beneficiary,
        bytes32 offerHash,
        uint256[8] memory fundingOptions,
        address investor,
        uint256 filled,
        uint256 amount
    ) external payable;

    function refundContribution(
        address beneficiary,
        bytes32 offerHash,
        address investor,
        uint256 unfilled,
        uint256 contributionId
    ) external payable;
}
