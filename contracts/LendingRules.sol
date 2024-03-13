// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract LendingRules is Ownable {
  error TreasuryWalletZeroAddress();
  error InvalidNFTContractAddress();
  error InvalidDepositFee();
  error InvalidLendingPeriod();
  error UnsupportedStableCoin();

  struct SpecialTerms {
    uint256 depositFee;
    uint256 lendingPeriod;
  }

  mapping(address => bool) public stableCoins;
  address[] private _stableCoins;
  uint256 private _defaultDepositFee;
  uint256 private _defaultLendingPeriod;
  mapping(address => SpecialTerms) private _specialTerms;
  address private _treasuryWallet;

  event StableCoinSet(address indexed stableCoin, bool active);
  event DepositFeeSet(uint256 defaultDepositFee);
  event LendingPeriodSet(uint256 defaultLendingPeriod);
  event SpecialTermsSet(address indexed nftContract, uint256 depositFee, uint256 lendingPeriod);
  event TreasuryWalletUpdated(address newTreasuryWallet);

  constructor(
    address initialOwner,
    address treasuryWallet,
    uint256 defaultDepositFee,
    uint256 defaultLendingPeriod
  ) Ownable(initialOwner) {
    setTreasuryWallet(treasuryWallet);
    setDefaultDepositFee(defaultDepositFee);
    setDefaultLendingPeriod(defaultLendingPeriod);
  }

  function setDefaultDepositFee(uint256 defaultDepositFee) public onlyOwner {
    if (defaultDepositFee == 0) revert InvalidDepositFee();
    _defaultDepositFee = defaultDepositFee;
    emit DepositFeeSet(defaultDepositFee);
  }

  function setDefaultLendingPeriod(uint256 defaultLendingPeriod) public onlyOwner {
    if (defaultLendingPeriod == 0) revert InvalidLendingPeriod();
    _defaultLendingPeriod = defaultLendingPeriod;
    emit LendingPeriodSet(defaultLendingPeriod);
  }

  function setSpecialDepositFee(address nftContractAddress, uint256 depositFee) public onlyOwner {
    if (nftContractAddress == address(0)) revert InvalidNFTContractAddress();
    if (depositFee == 0) revert InvalidDepositFee();
    _specialTerms[nftContractAddress].depositFee = depositFee;
    emit SpecialTermsSet(nftContractAddress, depositFee, _specialTerms[nftContractAddress].lendingPeriod);
  }

  function setSpecialLendingPeriod(address nftContractAddress, uint256 lendingPeriod) public onlyOwner {
    if (nftContractAddress == address(0)) revert InvalidNFTContractAddress();
    if (lendingPeriod == 0) revert InvalidLendingPeriod();
    _specialTerms[nftContractAddress].lendingPeriod = lendingPeriod;
    emit SpecialTermsSet(nftContractAddress, _specialTerms[nftContractAddress].depositFee, lendingPeriod);
  }

  function setSpecialTerms(address nftContractAddress, uint256 depositFee, uint256 lendingPeriod) public onlyOwner {
    if (nftContractAddress == address(0)) revert InvalidNFTContractAddress();
    if (depositFee == 0) revert InvalidDepositFee();
    if (lendingPeriod == 0) revert InvalidLendingPeriod();
    _specialTerms[nftContractAddress] = SpecialTerms(depositFee, lendingPeriod);
    emit SpecialTermsSet(nftContractAddress, depositFee, lendingPeriod);
  }

  function getSpecialTerms(address nftContractAddress) public view returns (uint256 depositFee, uint256 lendingPeriod) {
    SpecialTerms memory terms = _specialTerms[nftContractAddress];
    depositFee = terms.depositFee != 0 ? terms.depositFee : _defaultDepositFee;
    lendingPeriod = terms.lendingPeriod != 0 ? terms.lendingPeriod : _defaultLendingPeriod;
  }

  function setTreasuryWallet(address newTreasuryWallet) public onlyOwner {
    if (newTreasuryWallet == address(0)) revert TreasuryWalletZeroAddress();
    _treasuryWallet = newTreasuryWallet;
    emit TreasuryWalletUpdated(newTreasuryWallet);
  }

  function setStableCoin(address stableCoin, bool active) external virtual onlyOwner {
    if (active) {
      // We check if less than 6 because TetherUSD has 6 decimals
      // It should revert if the stableCoin is not an ERC20
      if (ERC20(stableCoin).decimals() < 6) {
        revert UnsupportedStableCoin();
      }
      if (!stableCoins[stableCoin]) {
        stableCoins[stableCoin] = true;
        _stableCoins.push(stableCoin);
        emit StableCoinSet(stableCoin, active);
      }
    } else if (stableCoins[stableCoin]) {
      delete stableCoins[stableCoin];
      // no risk of going out of cash because the factory will support just a couple of stable coins
      for (uint256 i; i < _stableCoins.length; ) {
        if (_stableCoins[i] == stableCoin) {
          _stableCoins[i] = _stableCoins[_stableCoins.length - 1];
          _stableCoins.pop();
          break;
        }
        unchecked {
          i++;
        }
      }
      emit StableCoinSet(stableCoin, active);
    }
  }

  function getStableCoins() external view virtual returns (address[] memory) {
    return _stableCoins;
  }

  function getTreasuryWallet() public view returns (address) {
    return _treasuryWallet;
  }
}
