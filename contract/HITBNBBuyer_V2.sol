// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IPancakeRouter {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract HITBNBBuyer is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public owner;
    address public immutable usdt;
    address public immutable hitbnb;
    address public immutable roiWallet;
    address public immutable router;

    event TokenSwapped(address indexed user, uint256 usdtAmount, uint256 minOut, uint256 timestamp);
    event EmergencyWithdraw(address indexed token, address indexed to, uint256 amount);
    event EmergencyBNBWithdraw(address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor(
        address _usdt,
        address _hitbnb,
        address _roiWallet,
        address _router
    ) {
        require(_usdt != address(0), "Invalid USDT address");
        require(_hitbnb != address(0), "Invalid HITBNB address");
        require(_roiWallet != address(0), "Invalid ROI wallet");
        require(_router != address(0), "Invalid router");

        owner = msg.sender;
        usdt = _usdt;
        hitbnb = _hitbnb;
        roiWallet = _roiWallet;
        router = _router;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner is zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function deposit(uint256 amount, uint256 amountOutMin) external nonReentrant {
        IERC20(usdt).safeTransferFrom(msg.sender, address(this), amount);

        uint256 currentAllowance = IERC20(usdt).allowance(address(this), router);
        if (currentAllowance < amount) {
            IERC20(usdt).approve(router, 0);
            IERC20(usdt).approve(router, type(uint256).max);
        }

        address[] memory path = new address[](2);
            path[0] = usdt;
            path[1] = hitbnb;
        
        IPancakeRouter(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount,
            amountOutMin,
            path,
            roiWallet,
            block.timestamp + 300
        );

        emit TokenSwapped(msg.sender, amount, amountOutMin, block.timestamp);
    }

    function emergencyWithdraw(address token, address to) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No token balance");
        IERC20(token).safeTransfer(to, balance);
        emit EmergencyWithdraw(token, to, balance);
    }

    function emergencyWithdrawBNB(address payable to) external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No BNB balance");
        to.transfer(balance);
        emit EmergencyBNBWithdraw(to, balance);
    }

    receive() external payable {}
}
