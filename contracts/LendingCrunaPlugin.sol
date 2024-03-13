// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.13;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILendingRules} from "./ILendingRules.sol";
import {LendingCrunaPluginBase} from "./LendingCrunaPluginBase.sol";

abstract contract LendingCrunaPlugin is LendingCrunaPluginBase {
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

  event AssetReceived(
    address indexed assetAddress,
    uint256 indexed tokenId,
    address depositor,
    uint256 depositTime,
    uint256 lendingPeriod
  );

  struct DepositDetail {
    address depositor;
    uint256 withdrawableAfter;
  }

  // TRT deploys the LendingRules contract, we need the deployer address who did that.
  // Create a mock of the plugin and set the lendingRules address to the address of the LendingRules contract.

  mapping(address => mapping(uint256 => DepositDetail)) private _depositedAssets;

  ILendingRules public lendingRulesAddress;

  function _nameId() internal view virtual override returns (bytes4) {
    return bytes4(keccak256("LendingCrunaPlugin"));
  }

  function setLendingRulesAddress(address _lendingRulesAddress) external onlyTokenOwner {
    if (_lendingRulesAddress == address(0)) {
      revert InvalidLendingRulesAddress();
    }
    lendingRulesAddress = ILendingRules(_lendingRulesAddress);
  }

  // Function to handle the deposit of an ERC721 token
  function depositAsset(address assetAddress, uint256 tokenId, address stableCoin) public {
    // Ensure the lendingRules contract has been set.
    if (address(lendingRulesAddress) == address(0)) {
      revert LendingRulesNotSet();
    }

    if (!lendingRulesAddress.isStableCoinSupported(stableCoin)) {
      revert UnsupportedStableCoin();
    }

    // Retrieve both the deposit fee and the lending period for the asset.
    (uint256 depositFee, uint256 lendingPeriod) = lendingRulesAddress.getDepositFee(assetAddress);

    // Check if the stablecoin balance is sufficient for the deposit fee.
    if (IERC20(stableCoin).balanceOf(msg.sender) < depositFee) {
      revert InsufficientFunds();
    }

    // Transfer the asset to the plugin contract and record the deposit.
    _depositedAssets[assetAddress][tokenId] = DepositDetail(msg.sender, block.timestamp + lendingPeriod);
    IERC721(assetAddress).safeTransferFrom(msg.sender, address(this), tokenId);
    emit AssetReceived(assetAddress, tokenId, msg.sender, block.timestamp, lendingPeriod);

    // If a deposit fee is set, transfer it to the treasury wallet.
    if (depositFee > 0) {
      address treasuryWallet = lendingRulesAddress.getTreasuryWallet();
      IERC20(stableCoin).safeTransferFrom(msg.sender, treasuryWallet, depositFee);
    }
  }

  function withdrawAsset(address assetAddress, uint256 tokenId) public {
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

    // Transfer the asset back to the depositor.
    IERC721(assetAddress).safeTransferFrom(address(this), msg.sender, tokenId);
    emit AssetWithdrawn(assetAddress, tokenId, msg.sender);
  }

  uint256[50] private __gap; // Reserved space for future upgrades
}
