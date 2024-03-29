//SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.3;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import "./Token.sol";
import "./lib/PaymentRecipientUpgradable.sol";

contract Treasury is AccessControlUpgradeable, PaymentRecipientUpgradable {
    string public constant name = "Flair.Finance Treasury";

    string public constant version = "0.1";

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    event BoughtBack(address initiator, uint256 ethAmount, uint256 tokensBought);
    event Burnt(address initiator, uint256 ethAmount);

    Token private _tokenAddress;
    IUniswapV2Router02 private _uniswapRouter;

    function initialize(address payable uniswapRouter) public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(GOVERNOR_ROLE, _msgSender());

        _uniswapRouter = IUniswapV2Router02(uniswapRouter);
    }

    //
    // Modifiers
    //
    modifier isGovernor() {
        require(hasRole(GOVERNOR_ROLE, _msgSender()), "TOKEN/NOT_GOVERNOR");
        _;
    }

    //
    // Admin functions
    //
    function setTokenAddress(address tokenAddress) public isGovernor() {
        _tokenAddress = Token(tokenAddress);
    }

    function buybackAndBurn(uint256 ethAmount, uint256 amountOutMin) public isGovernor() {
        require(ethAmount >= address(this).balance, "TOKEN/NOT_ENOUGH_TOKENS");
        require(address(_tokenAddress) != address(0), "TOKEN/INVALID_TOKEN_ADDRESS");

        // Build arguments for uniswap router call
        address[] memory path = new address[](2);
        path[0] = _uniswapRouter.WETH();
        path[1] = address(_tokenAddress);

        // Make the call and give it 30 seconds
        uint256[] memory amounts =
            _uniswapRouter.swapExactETHForTokens{value: ethAmount}(
                amountOutMin,
                path,
                address(this),
                block.timestamp + 30
            );
        uint256 amountBought = amounts[amounts.length - 1];
        emit BoughtBack(_msgSender(), ethAmount, amountBought);

        _tokenAddress.burn(amountBought);
        emit Burnt(_msgSender(), amountBought);
    }
}
