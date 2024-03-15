// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILendingRules} from "./ILendingRules.sol";
import {LendingCrunaPluginBase} from "./LendingCrunaPluginBase.sol";
import {ILendingCrunaPlugin} from "./ILendingCrunaPlugin.sol";

contract LendingCrunaPlugin is LendingCrunaPluginBase {
  using SafeERC20 for IERC20;

  modifier canWithdraw(address assetAddress, uint256 tokenId) {
    DepositDetail storage depositDetail = _depositedAssets[assetAddress][tokenId];
    if (depositDetail.depositor != msg.sender) {
      revert NotDepositor(msg.sender, depositDetail.depositor);
    }
    if (block.timestamp < depositDetail.withdrawableAfter) {
      revert WithdrawalNotAllowedYet(block.timestamp, depositDetail.withdrawableAfter);
    }
    _;
  }

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
  error InvalidSourcePlugin();
  error AssetAlreadyDeposited();
  error InvalidTargetPlugin();

  event AssetTransferredToPlugin(
    address indexed assetAddress,
    uint256 indexed tokenId,
    address indexed fromDepositor,
    address toPlugin
  );
  event AssetReceived(address indexed assetAddress, uint256 indexed tokenId, address depositor, uint256 lendingPeriod);
  event AssetReceivedFromPlugin(
    address indexed assetAddress,
    uint256 indexed tokenId,
    address indexed previousDepositor,
    uint256 lendingPeriod
  );

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

  function depositFromPlugin(address assetAddress, uint256 tokenId, address fromPlugin, address stableCoin) external {
    // Verify the fromPlugin is a legitimate LendingCrunaPlugin by checking if it supports the ILendingCrunaPlugin interface
    if (!ILendingCrunaPlugin(fromPlugin).supportsInterface(type(ILendingCrunaPlugin).interfaceId)) {
      revert InvalidSourcePlugin();
    }

    // Call depositAsset to handle the actual deposit process under the new plugin's terms
    depositAsset(assetAddress, tokenId, stableCoin);
  }

  function withdrawAsset(address assetAddress, uint256 tokenId, address withdrawTo) public canWithdraw(assetAddress, tokenId) {
    // Remove the asset from the deposited assets mapping.
    delete _depositedAssets[assetAddress][tokenId];

    // If withdrawTo is a zero address send back to depositor, otherwise send to withdrawTo.
    address to = withdrawTo == address(0) ? msg.sender : withdrawTo;

    // Transfer the asset back to the depositor.
    IERC721(assetAddress).safeTransferFrom(address(this), to, tokenId);
  }

  function withdrawAssetToPlugin(
    address assetAddress,
    uint256 tokenId,
    address toPlugin,
    address stableCoin
  ) public canWithdraw(assetAddress, tokenId) {
    // Ensure the target plugin supports the ILendingCrunaPlugin interface.
    if (!ILendingCrunaPlugin(toPlugin).supportsInterface(type(ILendingCrunaPlugin).interfaceId)) {
      revert InvalidTargetPlugin();
    }

    // Transfer the NFT to the target plugin.
    IERC721(assetAddress).safeTransferFrom(address(this), toPlugin, tokenId);

    // Call `depositFromPlugin` on the target plugin to deposit the NFT under new terms.
    ILendingCrunaPlugin(toPlugin).depositFromPlugin(assetAddress, tokenId, address(this), stableCoin);

    // Remove the asset from the deposited assets mapping after successful transfer and deposit.
    delete _depositedAssets[assetAddress][tokenId];

    // Emit an event for successful transfer and deposit to another plugin.
    emit AssetTransferredToPlugin(assetAddress, tokenId, msg.sender, toPlugin);
  }

  uint256[50] private __gap; // Reserved space for future upgrades
}
