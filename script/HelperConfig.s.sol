// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH price
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ETH_ANVIL_CHAIN_ID = 31337;
    uint256 public constant ENTRANCE_FEE = 0.1 ether;
    uint256 public constant INTERVAL = 30 seconds;
    uint256 public constant SUBSCRIPTION_FUND_AMOUNT = 0.1 ether;
}

contract HelperConfig is CodeConstants, Script {
    error HelperConfig__InvalidChainId();

    NetworkConfig public activeNetworkConfig;
    mapping(uint256 => NetworkConfig) public networkConfigs;

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subId;
        uint32 callbackGasLimit;
        address link; 
    }

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == 31337) {
            return getAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory sepoliaConfig) {
        sepoliaConfig = NetworkConfig({
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 2_500_000,
            subId: 66498156362016622606926862000765147562706128745410374599638249857117939832794,
            entranceFee: ENTRANCE_FEE,
            interval: INTERVAL, 
            link: 0x514910771AF9Ca656af840dff83E8264EcF986CA
        });
    }

    function getAnvilEthConfig() public returns (NetworkConfig memory anvilConfig) {
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UINT_LINK);
        LinkToken linkToken = new LinkToken(); 
        vm.stopBroadcast();
        anvilConfig = NetworkConfig({
            vrfCoordinator: address(vrfCoordinatorV2_5Mock),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 2_500_000,
            subId: 0,
            entranceFee: ENTRANCE_FEE,
            interval: INTERVAL, 
            link: address(linkToken)
        });
    }

    function setActiveNetworkConfig(NetworkConfig memory config) public {
        activeNetworkConfig = config;
    }
}