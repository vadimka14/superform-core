#!/usr/bin/env bash
# Note: How to set defaultKey - https://www.youtube.com/watch?v=VQe7cIpaE54

export ETHEREUM_RPC_URL=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ETHEREUM_RPC_URL/credential)
export BSC_RPC_URL=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BSC_RPC_URL/credential)
export AVALANCHE_RPC_URL=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/AVALANCHE_RPC_URL/credential)
export POLYGON_RPC_URL=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/POLYGON_RPC_URL/credential)
export ARBITRUM_RPC_URL=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ARBITRUM_RPC_URL/credential)
export OPTIMISM_RPC_URL=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/OPTIMISM_RPC_URL/credential)
export BASE_RPC_URL=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_RPC_URL/credential)

echo Adding paymaster and lifi validator v2 to super registry ...

FOUNDRY_PROFILE=production forge script script/forge-scripts/misc/Mainnet.SuperRegistryLiFiValidatorV2Paymaster.s.sol:MainnetSuperRegistryLiFiValidatorV2Paymaster --sig "configureSuperRegistry(uint256,uint256)" 0 0 --rpc-url $ETHEREUM_RPC_URL --slow --sender 0xFbcE385e2B8b7d6CeA52B4b971E31Af509e9B05A

wait

FOUNDRY_PROFILE=production forge script script/forge-scripts/misc/Mainnet.SuperRegistryLiFiValidatorV2Paymaster.s.sol:MainnetSuperRegistryLiFiValidatorV2Paymaster --sig "configureSuperRegistry(uint256,uint256)" 0 1 --rpc-url $BSC_RPC_URL --slow --sender 0xFbcE385e2B8b7d6CeA52B4b971E31Af509e9B05A

wait

FOUNDRY_PROFILE=production forge script script/forge-scripts/misc/Mainnet.SuperRegistryLiFiValidatorV2Paymaster.s.sol:MainnetSuperRegistryLiFiValidatorV2Paymaster --sig "configureSuperRegistry(uint256,uint256)" 0 2 --rpc-url $AVALANCHE_RPC_URL --slow --sender 0xFbcE385e2B8b7d6CeA52B4b971E31Af509e9B05A

wait

FOUNDRY_PROFILE=production forge script script/forge-scripts/misc/Mainnet.SuperRegistryLiFiValidatorV2Paymaster.s.sol:MainnetSuperRegistryLiFiValidatorV2Paymaster --sig "configureSuperRegistry(uint256,uint256)" 0 3 --rpc-url $POLYGON_RPC_URL --slow --sender 0xFbcE385e2B8b7d6CeA52B4b971E31Af509e9B05A

wait

FOUNDRY_PROFILE=production forge script script/forge-scripts/misc/Mainnet.SuperRegistryLiFiValidatorV2Paymaster.s.sol:MainnetSuperRegistryLiFiValidatorV2Paymaster --sig "configureSuperRegistry(uint256,uint256)" 0 4 --rpc-url $ARBITRUM_RPC_URL --slow --sender 0xFbcE385e2B8b7d6CeA52B4b971E31Af509e9B05A --legacy

wait

FOUNDRY_PROFILE=production forge script script/forge-scripts/misc/Mainnet.SuperRegistryLiFiValidatorV2Paymaster.s.sol:MainnetSuperRegistryLiFiValidatorV2Paymaster --sig "configureSuperRegistry(uint256,uint256)" 0 5 --rpc-url $OPTIMISM_RPC_URL --slow --sender 0xFbcE385e2B8b7d6CeA52B4b971E31Af509e9B05A

wait

FOUNDRY_PROFILE=production forge script script/forge-scripts/misc/Mainnet.SuperRegistryLiFiValidatorV2Paymaster.s.sol:MainnetSuperRegistryLiFiValidatorV2Paymaster --sig "configureSuperRegistry(uint256,uint256)" 0 6 --rpc-url $BASE_RPC_URL --slow --sender 0xFbcE385e2B8b7d6CeA52B4b971E31Af509e9B05A
