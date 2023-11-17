// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

interface IVotingEscrow {
    struct Point {
        int128 bias;
        int128 slope; // # -dweight / dt
        uint256 ts;
        uint256 blk; // block
    }
    /*//////////////////////////////////////////////////////////////
                             ESCROW STORAGE
    //////////////////////////////////////////////////////////////*/

    function get_last_user_slope(address sender) external view returns (int128);

    function user_point_history__ts(address sender, uint256 _idx) external view returns (uint256);
    function locked__end(address sender) external view returns (uint256);

    /// @notice Record global data to checkpoint
    function checkpoint() external;

    function deposit_for(address sender, uint256 _value) external;

    /// @notice Deposit `_value` tokens for `msg.sender` and lock for `_lock_duration`
    /// @param _value Amount to deposit
    /// @param _lock_duration Number of seconds to lock tokens for (rounded down to nearest week)
    function create_lock(uint256 _value, uint256 _lock_duration) external;
    /// @notice Deposit `_value` tokens for `_to` and lock for `_lock_duration`
    /// @param _value Amount to deposit
    /// @param _lock_duration Number of seconds to lock tokens for (rounded down to nearest week)
    /// @param _to Address to deposit
    function create_lock_for(uint256 _value, uint256 _lock_duration, address _to) external;
    /// @notice Deposit `_value` additional tokens for `address sender` without modifying the unlock time
    /// @param _value Amount of tokens to deposit and add to the lock
    function increase_amount(address sender, uint256 _value) external;

    /// @notice Extend the unlock time for `address sender`
    /// @param _lock_duration New number of seconds until tokens unlock
    function increase_unlock_time(address sender, uint256 _lock_duration) external;

    /// @notice Withdraw all tokens for `address sender`
    /// @dev Only possible if the lock has expired
    function withdraw(address sender) external;

    function balanceOfNFT(address sender) external view returns (uint256);
    function balanceOfNFTAt(address sender, uint256 _t) external view returns (uint256);

    function balanceOfAtNFT(address sender, uint256 _block) external view returns (uint256);
    /// @notice Calculate total voting power at some point in the past
    /// @param _block Block to calculate the total voting power at
    /// @return Total voting power at `_block`
    function totalSupplyAt(uint256 _block) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    /// @notice Calculate total voting power
    /// @dev Adheres to the ERC20 `totalSupply` interface for Aragon compatibility
    /// @return Total voting power
    function totalSupplyAtT(uint256 t) external view returns (uint256);

    function setVoter(address _voter) external;

    function voting(address sender) external;

    function abstain(address sender) external;

    function attach(address sender) external;

    function detach(address sender) external;
}
