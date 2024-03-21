// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.13;

interface ILendingRules {
  function getSpecialTerms(address nftContractAddress) external view returns (uint256 depositFee, uint256 lendingPeriod);
  function getTreasuryWallet() external view returns (address);
  function getDefaultDepositFee() external view returns (uint256);

  function setDefaultDepositFee(uint256 defaultDepositFee) external;
  function setDefaultLendingPeriod(uint256 defaultLendingPeriod) external;

  function setSpecialDepositFee(address nftContractAddress, uint256 depositFee) external;
  function setSpecialLendingPeriod(address nftContractAddress, uint256 lendingPeriod) external;
  function setSpecialTerms(address nftContractAddress, uint256 depositFee, uint256 lendingPeriod) external;

  function setTreasuryWallet(address newTreasuryWallet) external;
  function setStableCoin(address stableCoin, bool active) external;
  function getStableCoins() external view returns (address[] memory);
  function isStableCoinSupported(address stableCoin) external view returns (bool);
}
