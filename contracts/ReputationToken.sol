// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ReputationToken is ERC20, Ownable {
    constructor() ERC20("ReputationToken", "RPT") {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DeFi is Ownable {
    using SafeMath for uint256;

    // Structure to represent each user
    struct User {
        // uint256 ethBalance; // Ether balance in the user's wallet
        uint256 usdBalance; // USD balance in the user's wallet
        uint256 mortgagedEth; // Amount of Ether mortgaged by the user
        uint256 lastPaymentTimestamp; // Timestamp of the user's last payment
    }

    // Structure to represent each investment
    struct Investment {
        address investor; // Address of the investor
        uint256 amount; // Amount invested by the investor
    }

    // Mapping of user addresses to their details
    mapping(address => User) public users;

    // Mapping of investments made by investors
    mapping(address => Investment) public investments;

    // Wallet for storing mortgaged Ether
    address public commonWallet;

    // Wallet for storing investments
    address public investmentWallet;

    // Default ETH to USD value
    uint256 public constant ethToUsd = 4000;

    // Loan to Value (LTV) ratio (percentage of ETH value given as loan)
    uint256 public constant loanToValueRatio = 80;

    // Interest rate for borrowers (in percentage)
    uint256 public constant borrowerInterestRate = 7;

    // Interest rate for lenders (in percentage)
    uint256 public constant lenderInterestRate = 6;

    // Penalty rate for missed EMI payments (in percentage)
    uint256 public constant penaltyRate = 7;

    // Event to log when a user mortgages Ether
    event EtherMortgaged(address indexed user, uint256 amount);

    // Event to log when a user withdraws their mortgaged Ether
    event EtherWithdrawn(address indexed user, uint256 amount);

    // Event to log when an investor invests in the common wallet
    event InvestmentMade(address indexed investor, uint256 amount);

    // Event to log when a borrower pays EMI
    event EMIPaid(address indexed borrower, uint256 amount);

    constructor(address _commonWallet, address _investmentWallet) {

        commonWallet = _commonWallet;
        investmentWallet = _investmentWallet;
    }

    // Function for users to mortgage Ether and receive USD
    function mortgageEther() external payable {
        require(msg.value > 0, "Mortgage amount must be greater than 0");

        // Calculate the USD amount based on the mortgage amount and ETH to USD conversion rate
        uint256 usdAmount = msg.value.mul(ethToUsd);

        // Calculate the mortgaged ETH amount based on the Loan to Value (LTV) ratio
        uint256 mortgagedEth = msg.value.mul(100).div(loanToValueRatio);

        // Update user balances and common wallet balance
        // users[msg.sender].ethBalance -= mortgagedEth;
        users[msg.sender].usdBalance += usdAmount;
        users[msg.sender].mortgagedEth += mortgagedEth;
        payable(commonWallet).transfer(msg.value);

        emit EtherMortgaged(msg.sender, msg.value);
    }

    // Function for users to withdraw their mortgaged Ether
    function payEMI(uint256 amount) external {
    require(amount > 0, "EMI amount must be greater than 0");
    require(users[msg.sender].usdBalance >= amount, "Insufficient USD balance");

    // Calculate penalty for late payment
    uint256 penaltyAmount = calculatePenalty(amount);

    // Update user balance
    users[msg.sender].usdBalance -= amount;

    // Transfer penalty to the contract owner
    payable(owner()).transfer(penaltyAmount);

    // Check if the EMI for a month has been paid
    if (block.timestamp >= users[msg.sender].lastPaymentTimestamp + 30 days) {
        // Calculate the equivalent amount of ETH based on the EMI amount
        uint256 equivalentEthAmount = amount.div(ethToUsd);
        // Add the equivalent ETH amount to the user's balance
        payable(commonWallet).transfer(equivalentEthAmount);
    }

    emit EMIPaid(msg.sender, amount);
}


    // Function to calculate penalty for late payment
    function calculatePenalty(uint256 amount) private view returns (uint256) {
        uint256 penaltyAmount = 0;
        if (block.timestamp > users[msg.sender].lastPaymentTimestamp + 30 days) {
            penaltyAmount = amount.mul(penaltyRate).div(100);
        }
        return penaltyAmount;
    }

    // Function for investors to invest in the common wallet
    function invest() external payable {
        require(msg.value > 0, "Investment amount must be greater than 0");

        // Update investment details

        investments[msg.sender].investor = msg.sender;
        investments[msg.sender].amount += msg.value;
        payable(investmentWallet).transfer(msg.value);
        emit InvestmentMade(msg.sender, msg.value);
    }
    

    // Function to withdraw funds from the contract (only owner)
    function withdrawFunds(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient contract balance");
        payable(owner()).transfer(amount);
    }
    // Function to get the details of a user by address
function getUserDetails(address userAddress) external view returns (
    // uint256 ethBalance,
    uint256 usdBalance,
    uint256 mortgagedEth,
    uint256 lastPaymentTimestamp
) {
    // Retrieve user details from the mapping
    User storage user = users[userAddress];
    return (
       // user.ethBalance,
        user.usdBalance,
        user.mortgagedEth,
        user.lastPaymentTimestamp
    );
}
// Function to add money to a user's USD balance
function addUsdBalance(address userAddress, uint256 amount) external {
    // Update the user's USD balance
    users[userAddress].usdBalance += amount;
}

}