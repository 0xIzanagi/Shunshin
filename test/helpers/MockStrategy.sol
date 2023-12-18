// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import {IStrategy} from "../../src/Vaults/interfaces/IStrategy.sol";
import {ERC20} from "oz/token/ERC20/ERC20.sol";

contract MockStrategy is ERC20, IStrategy {
    ERC20 private immutable _asset;
    uint256 private _maxDeposit;

    constructor(address _asset_) ERC20("MockStrat", "MSTRAT") {
        _asset = ERC20(_asset_);
    }

    function asset() external view override returns (address) {
        return address(_asset);
    }

    function balanceOf(address) public view override(IStrategy, ERC20) returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    function maxDeposit(address) external view returns (uint256) {
        return _maxDeposit;
    }

    function redeem(uint256 amount, address receiver, address) external returns (uint256) {
        _asset.transfer(receiver, amount);
    }

    function deposit(uint256 value, address) external returns (uint256) {
        _asset.transferFrom(msg.sender, address(this), value);
    }

    function totalAssets() external view returns (uint256) {}

    function convertToAssets(uint256) external view returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    function convertToShares(uint256) external view returns (uint256) {}

    function previewWithdraw(uint256) external view returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    function maxRedeem(address) external view returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    function setMaxDeposit(uint256 amount) external {
        _maxDeposit = amount;
    }
}
