// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
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

contract AutoSwapHITBNB {
    address public constant USDT = 0x55d398326f99059fF775485246999027B3197955; // BSC USDT
    address public hitbnbAddress;
    address public owner;
    address public roiWallet;
    IPancakeRouter public constant pancakeRouter = IPancakeRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    
    event DepositedAndSwapped(address indexed user, uint256 usdtAmount, uint256 hitbnbReceived);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _hitbnbAddress, address _roiWallet) {
        hitbnbAddress = _hitbnbAddress;
        roiWallet = _roiWallet;
        owner = msg.sender;
    }

    // AUTO PROCESS: Deposit USDT -> Swap to HITBNB -> Send to ROI Wallet
    function depositAndSwap(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        
        // 1. Transfer USDT from user to contract
        require(IERC20(USDT).transferFrom(msg.sender, address(this), amount), "USDT transfer failed");
        
        // 2. Approve PancakeSwap to spend USDT
        IERC20(USDT).approve(address(pancakeRouter), amount);
        
        // 3. Swap USDT to HITBNB
        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = hitbnbAddress;
        
        uint256 hitbnbBefore = IERC20(hitbnbAddress).balanceOf(address(this));
        pancakeRouter.swapExactTokensForTokens(
            amount,
            0, // Minimum amount out 
            path,
            address(this),
            block.timestamp + 300 // 5 min deadline
        );
        uint256 hitbnbAfter = IERC20(hitbnbAddress).balanceOf(address(this));
        uint256 hitbnbReceived = hitbnbAfter - hitbnbBefore;
        
        // 4. Transfer HITBNB to ROI Wallet
        require(IERC20(hitbnbAddress).transfer(roiWallet, hitbnbReceived), "HITBNB transfer failed");
        
        emit DepositedAndSwapped(msg.sender, amount, hitbnbReceived);
    }

    // For emergency cases (e.g. if swap fails)
    function manualTransferHITBNB() external onlyOwner {
        uint256 balance = IERC20(hitbnbAddress).balanceOf(address(this));
        require(balance > 0, "No HITBNB balance");
        require(IERC20(hitbnbAddress).transfer(roiWallet, balance), "Transfer failed");
    }

    // Admin functions
    function updateTokenAddresses(address _hitbnbAddress) external onlyOwner {
        hitbnbAddress = _hitbnbAddress;
    }

    function updateROIWallet(address _roiWallet) external onlyOwner {
        roiWallet = _roiWallet;
    }

    // Recover accidentally sent tokens
    function recoverERC20(address tokenAddress) external onlyOwner {
        require(tokenAddress != hitbnbAddress, "Cannot recover HITBNB");
        uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
        IERC20(tokenAddress).transfer(owner, balance);
    }
}