// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract LendingRules is Ownable {
  error TreasuryWalletZeroAddress();
  error InvalidNFTContractAddress();
  error InvalidDepositFee();

  uint256 private _defaultDepositFee;
  mapping(address => uint256) private _specialDepositFees;
  address private _treasuryWallet;

  event DepositFeeSet(uint256 defaultDepositFee);
  event SpecialDepositFeeSet(address indexed nftContract, uint256 depositFee);
  event TreasuryWalletUpdated(address newTreasuryWallet);

  // Add setStableCoin function, which sets up which stable coins we accept.
  // Check vaultFactory for that code and approach.

  constructor(address initialOwner, address treasuryWallet, uint256 defaultDepositFee) Ownable(initialOwner) {
    setTreasuryWallet(treasuryWallet);
    setDefaultDepositFee(defaultDepositFee);
  }

  //  function setStableCoin(address stableCoin, bool active) external virtual override onlyOwner {
  //    if (active) {
  //      // We check if less than 6 because TetherUSD has 6 decimals
  //      // It should revert if the stableCoin is not an ERC20
  //      if (ERC20(stableCoin).decimals() < 6) {
  //        revert UnsupportedStableCoin();
  //      }
  //      if (!stableCoins[stableCoin]) {
  //        stableCoins[stableCoin] = true;
  //        _stableCoins.push(stableCoin);
  //        emit StableCoinSet(stableCoin, active);
  //      }
  //    } else if (stableCoins[stableCoin]) {
  //      delete stableCoins[stableCoin];
  //      // no risk of going out of cash because the factory will support just a couple of stable coins
  //      for (uint256 i; i < _stableCoins.length; ) {
  //        if (_stableCoins[i] == stableCoin) {
  //          _stableCoins[i] = _stableCoins[_stableCoins.length - 1];
  //          _stableCoins.pop();
  //          break;
  //        }
  //        unchecked {
  //          i++;
  //        }
  //      }
  //      emit StableCoinSet(stableCoin, active);
  //    }
  //  }

  // Set the default deposit fee
  function setDefaultDepositFee(uint256 defaultDepositFee) public onlyOwner {
    if (defaultDepositFee == 0) revert InvalidDepositFee();
    _defaultDepositFee = defaultDepositFee;
    emit DepositFeeSet(defaultDepositFee);
  }

  // Set a special deposit fee for a specific NFT collection
  function setSpecialDepositFee(address nftContractAddress, uint256 depositFee) public onlyOwner {
    if (nftContractAddress == address(0)) revert InvalidNFTContractAddress();
    if (depositFee == 0) revert InvalidDepositFee();
    _specialDepositFees[nftContractAddress] = depositFee;
    emit SpecialDepositFeeSet(nftContractAddress, depositFee);
  }

  // Retrieve the deposit fee for an NFT collection, returning the default if no special fee is set
  function getDepositFee(address nftContractAddress) public view returns (uint256) {
    uint256 specialFee = _specialDepositFees[nftContractAddress];
    return specialFee != 0 ? specialFee : _defaultDepositFee;
  }

  function setTreasuryWallet(address newTreasuryWallet) public onlyOwner {
    if (newTreasuryWallet == address(0)) revert TreasuryWalletZeroAddress();
    _treasuryWallet = newTreasuryWallet;
    emit TreasuryWalletUpdated(newTreasuryWallet);
  }

  function getTreasuryWallet() public view returns (address) {
    return _treasuryWallet;
  }
}
