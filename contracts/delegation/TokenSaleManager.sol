pragma solidity ^0.5.3;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";

import "../interfaces/tokenSale/ITokenSaleManager.sol";
import "../interfaces/delegation/IDelegatableToken.sol";
import "../Permissions.sol";
import "./DelegationService.sol";


contract TokenSaleManager is ITokenSaleManager, Permissions, IERC777Recipient {
    IERC1820Registry private _erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    address seller;

    mapping (address => uint) approved;
    uint totalApproved;

    constructor(address _contractManager) Permissions(_contractManager) public {
        _erc1820.setInterfaceImplementer(address(this), keccak256("ERC777TokensRecipient"), address(this));
    }

    /// @notice Allocates values for `walletAddresses`
    function approve(address[] calldata walletAddress, uint[] calldata value) external {
        require(isOwner() || _msgSender() == seller, "Not authorized");
        require(walletAddress.length == value.length, "Wrong input arrays length");
        for (uint i = 0; i < walletAddress.length; ++i) {
            approved[walletAddress[i]] += value[i];
            totalApproved += value[i];
        }
        require(totalApproved <= getBalance(), "Balance is too low");
    }

    /// @notice Transfers the entire value to sender address. Tokens are locked.
    function retrieve() external {
        require(approved[_msgSender()] > 0, "Transfer is not approved");
        uint value = approved[_msgSender()];
        approved[_msgSender()] = 0;
        require(IERC20(contractManager.getContract("SkaleToken")).transfer(_msgSender(), value), "Error of token sending");
        DelegationService(contractManager.getContract("DelegationService")).lock(_msgSender(), value);
    }

    function registerSeller(address _seller) external onlyOwner {
        seller = _seller;
    }

    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    )
        external
    {

    }

    // internal

    function getBalance() internal returns(uint balance) {
        return IERC20(contractManager.getContract("SkaleToken")).balanceOf(address(this));
    }
}