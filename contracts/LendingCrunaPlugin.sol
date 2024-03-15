// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.13;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILendingRules} from "./ILendingRules.sol";
import {LendingCrunaPluginBase} from "./LendingCrunaPluginBase.sol";

/*
 * @title Lending Cruna Plugin
 * @notice This contract is a fundamental component of a decentralized finance (DeFi) lending platform,
 * designed specifically for handling NFT assets. It enables users to deposit NFTs as collateral, unlocking
 * financial utility and access to lending services for NFT holders. The plugin interfaces with a set of lending
 * rules that define the terms under which NFTs can be lent, including but not limited to deposit fees and
 * lending periods.
 *
 * Users can deposit their NFT assets into the smart contract, which then securely manages the custody of these
 * assets, collects any applicable fees, and ensures compliance with the established lending rules. This system
 * democratizes the lending and borrowing process within the NFT domain, fostering enhanced liquidity and financial
 * innovation by allowing NFT owners to leverage their assets in new and impactful ways.
 */
contract LendingCrunaPlugin is LendingCrunaPluginBase {
  using SafeERC20 for IERC20;
  error InsufficientDepositFee(uint256 requiredFee, uint256 providedFee);
  error InsufficientFunds();
  error TransferFailed();
  error InvalidLendingRulesAddress();
  error NotDepositor(address caller, address expected);
  error TransferToTreasuryFailed();
  error TransferNotCompleted(address assetAddress, uint256 tokenId);
  error LendingRulesNotSet();
  error WithdrawalNotAllowedYet(uint256 requestTime, uint256 requiredTime);
  error StableCoinNotSupported();
  error UnsupportedStableCoin();

  event AssetReceived(address indexed assetAddress, uint256 indexed tokenId, address depositor, uint256 lendingPeriod);

  struct DepositDetail {
    address depositor;
    uint256 withdrawableAfter;
  }

  mapping(address => mapping(uint256 => DepositDetail)) private _depositedAssets;

  ILendingRules public lendingRulesAddress;

  function _nameId() internal view virtual override returns (bytes4) {
    return bytes4(keccak256("LendingCrunaPlugin"));
  }

  /*
   * @notice Function to set the lending rules contract address.
   * @param _lendingRulesAddress The address of the lending rules contract.
   */
  function setLendingRulesAddress(address _lendingRulesAddress) external onlyTokenOwner {
    if (_lendingRulesAddress == address(0)) {
      revert InvalidLendingRulesAddress();
    }
    lendingRulesAddress = ILendingRules(_lendingRulesAddress);
  }

  /*
   * @notice Function to deposit an NFT asset as collateral for a loan.
   * @dev Checks for stablecoin support and sufficient deposit fee before proceeding.
   * @param assetAddress The address of the NFT contract.
   * @param tokenId The ID of the NFT token being deposited.
   * @param stableCoin The address of the stablecoin used for the deposit fee.
   */
  function depositAsset(address assetAddress, uint256 tokenId, address stableCoin) public {
    // Ensure the lendingRules contract has been set.
    if (address(lendingRulesAddress) == address(0)) {
      revert LendingRulesNotSet();
    }

    if (!lendingRulesAddress.isStableCoinSupported(stableCoin)) {
      revert UnsupportedStableCoin();
    }

    // Retrieve both the deposit fee and the lending period for the asset.
    (uint256 depositFee, uint256 lendingPeriod) = lendingRulesAddress.getSpecialTerms(assetAddress);

    // Check if the stablecoin balance is sufficient for the deposit fee.
    if (IERC20(stableCoin).balanceOf(msg.sender) < depositFee) {
      revert InsufficientFunds();
    }

    // Transfer the asset to the plugin contract and record the deposit.
    _depositedAssets[assetAddress][tokenId] = DepositDetail(msg.sender, block.timestamp + lendingPeriod);
    IERC721(assetAddress).safeTransferFrom(msg.sender, address(this), tokenId);
    emit AssetReceived(assetAddress, tokenId, msg.sender, lendingPeriod);

    // If a deposit fee is set, transfer it to the treasury wallet.
    if (depositFee > 0) {
      address treasuryWallet = lendingRulesAddress.getTreasuryWallet();
      IERC20(stableCoin).safeTransferFrom(msg.sender, treasuryWallet, depositFee);
    }
  }

  /*
   * @notice Function to withdraw an NFT asset from the plugin contract.
   * @dev Validates the depositor and checks the withdrawable timestamp before proceeding.
   * @param assetAddress The address of the NFT contract.
   * @param tokenId The ID of the NFT token being withdrawn.
   * @param withdrawTo The address to withdraw the asset to, or the depositor's address if zero.
   */
  function withdrawAsset(address assetAddress, uint256 tokenId, address withdrawTo) public {
    DepositDetail memory depositDetail = _depositedAssets[assetAddress][tokenId];

    // Ensure only the depositor can initiate the withdrawal.
    if (depositDetail.depositor != msg.sender) {
      revert NotDepositor(msg.sender, depositDetail.depositor);
    }

    // Check if the current time is after the allowed withdrawal time.
    if (block.timestamp < depositDetail.withdrawableAfter) {
      revert WithdrawalNotAllowedYet(block.timestamp, depositDetail.withdrawableAfter);
    }

    // Remove the asset from the deposited assets mapping.
    delete _depositedAssets[assetAddress][tokenId];

    // If withdrawTo is a zero address send back to depositor, otherwise send to withdrawTo.
    address to = withdrawTo == address(0) ? msg.sender : withdrawTo;

    // Transfer the asset back to the depositor.
    IERC721(assetAddress).safeTransferFrom(address(this), to, tokenId);
  }

  uint256[50] private __gap; // Reserved space for future upgrades
}
