// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; 

abstract contract Events {
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
}