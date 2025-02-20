// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "./FFactory.sol";
import "../interface/IFPair.sol";

contract FRouter is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    FFactory public factory;
    address public bonding;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address factory_
    ) external initializer {
        __ReentrancyGuard_init();
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        require(factory_ != address(0), "Zero addresses are not allowed.");

        factory = FFactory(factory_);
    }

    function setBonding(address bonding_) public onlyRole(DEFAULT_ADMIN_ROLE) {
        bonding = bonding_;
    }


    function getAmountsOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public view returns (uint256 _amountOut) {
        require(tokenIn != address(0) && tokenOut != address(0), "Zero addresses are not allowed.");

        address pairAddress = factory.getPair(tokenIn, tokenOut);
        if (pairAddress == address(0)){
            pairAddress = factory.getPair(tokenOut, tokenIn);
        }

        IFPair pair = IFPair(pairAddress);

        (uint256 reserveA, uint256 reserveB) = pair.getReserves();

        address assetToken = pair.tokenB();

        uint256 k = pair.kLast();

        uint256 amountOut;

        if (tokenOut == assetToken) {
            uint256 newReserveB = reserveB + amountIn;

            uint256 newReserveA = k / newReserveB;

            amountOut = reserveA - newReserveA;
        } else {
            uint256 newReserveA = reserveA + amountIn;

            uint256 newReserveB = k / newReserveA;

            amountOut = reserveB - newReserveB;
        }

        return amountOut;
    }

    function addInitialLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) public onlyRole(EXECUTOR_ROLE) returns (uint256, uint256) {
        require(tokenA != address(0) && tokenB != address(0), "Zero addresses are not allowed.");

        address pairAddress = factory.getPair(tokenA, tokenB);

        IERC20(tokenA).safeTransferFrom(msg.sender, pairAddress, amountA);

        IFPair(pairAddress).mint(amountA, amountB);

        return (amountA, amountB);
    }

    function sell(
        uint256 amountIn,
        address pairAddress,
        address to
    ) public nonReentrant onlyRole(EXECUTOR_ROLE) returns (uint256, uint256) {
        require(pairAddress != address(0), "Zero addresses are not allowed.");
        require(to != address(0), "Zero addresses are not allowed.");

        IFPair pair = IFPair(pairAddress);

        address tokenAddress = pair.tokenA();

        uint256 amountOut = getAmountsOut(tokenAddress, address(0), amountIn);

        IERC20(tokenAddress).safeTransferFrom(to, pairAddress, amountIn);

        uint fee = factory.sellTax();
        uint256 txFee = (fee * amountOut) / 100;

        uint256 amount = amountOut - txFee;
        address feeTo = factory.taxVault();

        pair.transferAsset(to, amount);
        pair.transferAsset(feeTo, txFee);

        pair.swap(amountIn, 0, 0, amountOut);

        return (amountIn, amountOut);
    }

    function buy(
        uint256 amountIn,
        address pairAddress,
        address to
    ) public onlyRole(EXECUTOR_ROLE) nonReentrant returns (uint256, uint256) {
        require(pairAddress != address(0), "Zero addresses are not allowed.");
        require(to != address(0), "Zero addresses are not allowed.");
        require(amountIn > 0, "amountIn must be greater than 0");

        IFPair pair = IFPair(pairAddress);

        uint fee = factory.buyTax();
        uint256 txFee = (fee * amountIn) / 100;
        address feeTo = factory.taxVault();

        uint256 amount = amountIn - txFee;
        address tokenAddress = pair.tokenA();
        address assetToken = pair.tokenB();

        IERC20(assetToken).safeTransferFrom(to, pairAddress, amount);

        IERC20(assetToken).safeTransferFrom(to, feeTo, txFee);

        uint256 amountOut = getAmountsOut(tokenAddress, assetToken, amount);

        pair.transferTo(to, amountOut);

        pair.swap(0, amountOut, amount, 0);

        return (amount, amountOut);
    }

    function graduate(
        address pairAddress
    ) public onlyRole(EXECUTOR_ROLE) nonReentrant {
        require(pairAddress != address(0), "Zero addresses are not allowed.");

        IFPair pair = IFPair(pairAddress);

        uint256 assetBalance = pair.assetBalance();
        pair.transferAsset(msg.sender, assetBalance);
        uint256 balance = pair.balance();
        pair.transferTo(msg.sender, balance);
    }

    function approval(
        address pair,
        address asset,
        address spender,
        uint256 amount
    ) public onlyRole(EXECUTOR_ROLE) nonReentrant {
        require(spender != address(0), "Zero addresses are not allowed.");

        IFPair(pair).approval(spender, asset, amount);
    }
}
