// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IPancakeRouter {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract USDTtoHITBNB {
    address public usdtAddress;
    address public hitbnbAddress;
    address public owner;
    address public roiWallet;
    IPancakeRouter public pancakeRouter;
    
    mapping(address => bool) public whitelistedUsers;

    event Deposit(address indexed user, uint256 amount);
    event Swap(address indexed user, uint256 usdtAmount, uint256 hitbnbAmount);
    event TransferToROI(uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor(address _usdtAddress, address _hitbnbAddress, address _pancakeRouter, address _roiWallet) {
        usdtAddress = _usdtAddress;
        hitbnbAddress = _hitbnbAddress;
        pancakeRouter = IPancakeRouter(_pancakeRouter);
        roiWallet = _roiWallet;
        owner = msg.sender;
    }

    // Allow users to deposit USDT
    function depositUSDT(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(IERC20(usdtAddress).transferFrom(msg.sender, address(this), amount), "USDT transfer failed");
        emit Deposit(msg.sender, amount);
    }

    // Swap USDT for HITBNB tokens
    function swapUSDTForHITBNB(uint256 amountIn) external onlyOwner {
        uint256 balance = IERC20(usdtAddress).balanceOf(address(this));
        require(balance >= amountIn, "Insufficient USDT in contract");

        // Approve PancakeSwap to spend USDT
        IERC20(usdtAddress).approve(address(pancakeRouter), amountIn);

        address[] memory path = new address[](2);
        path[0] = usdtAddress;
        path[1] = hitbnbAddress;

        uint256 hitbnbBalanceBefore = IERC20(hitbnbAddress).balanceOf(address(this));
        
        pancakeRouter.swapExactTokensForTokens(
            amountIn,
            0, // Minimum amount out (no slippage protection for demo)
            path,
            address(this),
            block.timestamp
        );

        uint256 hitbnbBalanceAfter = IERC20(hitbnbAddress).balanceOf(address(this));
        uint256 hitbnbReceived = hitbnbBalanceAfter - hitbnbBalanceBefore;
        
        emit Swap(msg.sender, amountIn, hitbnbReceived);
    }

    // Transfer HITBNB to ROI wallet
    function transferHITBNBToROI() external onlyOwner {
        uint256 hitbnbBalance = IERC20(hitbnbAddress).balanceOf(address(this));
        require(hitbnbBalance > 0, "No HITBNB to transfer");
        
        require(IERC20(hitbnbAddress).transfer(roiWallet, hitbnbBalance), "Transfer failed");
        emit TransferToROI(hitbnbBalance);
    }

    // Admin functions
    function updateROIWallet(address newWallet) external onlyOwner {
        roiWallet = newWallet;
    }

    function withdrawUSDT() external onlyOwner {
        uint256 balance = IERC20(usdtAddress).balanceOf(address(this));
        require(balance > 0, "No USDT to withdraw");
        require(IERC20(usdtAddress).transfer(owner, balance), "Withdrawal failed");
    }

    function withdrawHITBNB() external onlyOwner {
        uint256 balance = IERC20(hitbnbAddress).balanceOf(address(this));
        require(balance > 0, "No HITBNB to withdraw");
        require(IERC20(hitbnbAddress).transfer(owner, balance), "Withdrawal failed");
    }
}