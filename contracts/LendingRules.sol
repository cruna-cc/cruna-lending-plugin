// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract LendingRules is Ownable {
  error TreasuryWalletZeroAddress();
  error InvalidNFTContractAddress();
  error UnauthorizedAccess();

  struct NFTContractConfig {
    bool isWhitelisted;
  }

  uint256 private _activationFee;
  mapping(address => NFTContractConfig) public whitelistedNFTContracts;
  address private _treasuryWallet;

  event NFTContractWhitelisted(address indexed nftContractAddress, bool isWhitelisted);
  event ActivationFeeSet(uint256 activationFee);
  event TreasuryWalletUpdated(address newTreasuryWallet);

  constructor(address initialOwner, address treasuryWallet, uint256 activationFee) Ownable(initialOwner) {
    if (treasuryWallet == address(0)) revert TreasuryWalletZeroAddress();
    _treasuryWallet = treasuryWallet;
    _activationFee = activationFee;
  }

  function whitelistNFTContract(address nftContractAddress, bool isWhitelisted) external onlyOwner {
    if (nftContractAddress == address(0)) revert InvalidNFTContractAddress();
    whitelistedNFTContracts[nftContractAddress].isWhitelisted = isWhitelisted;
    emit NFTContractWhitelisted(nftContractAddress, isWhitelisted);
  }

  function setActivationFee(uint256 activationFee) external onlyOwner {
    _activationFee = activationFee;
    emit ActivationFeeSet(activationFee);
  }

  function setTreasuryWallet(address newTreasuryWallet) external onlyOwner {
    if (newTreasuryWallet == address(0)) revert TreasuryWalletZeroAddress();
    _treasuryWallet = newTreasuryWallet;
    emit TreasuryWalletUpdated(newTreasuryWallet);
  }

  function isNFTContractWhitelisted(address nftContractAddress) public view returns (bool) {
    return whitelistedNFTContracts[nftContractAddress].isWhitelisted;
  }

  function getActivationFee() public view returns (uint256) {
    return _activationFee;
  }

  function getTreasuryWallet() public view returns (address) {
    return _treasuryWallet;
  }
}
