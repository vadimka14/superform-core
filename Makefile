# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env


# only export these env vars if ENVIRONMENT = local
ifeq ($(ENVIRONMENT), local)
	export TENDERLY_ACCESS_KEY := $(shell op read op://5ylebqljbh3x6zomdxi3qd7tsa/TENDERLY_ACCESS_KEY/credential)
	export ETHEREUM_RPC_URL = $(shell tenderly devnet spawn-rpc --project ${TENDERLY_PROJECT_SLUG} --template ethereum-devnet --account ${TENDERLY_ACCOUNT_ID} --access_key ${TENDERLY_ACCESS_KEY} --return-url)
	export BSC_RPC_URL := $(shell tenderly devnet spawn-rpc --project ${TENDERLY_PROJECT_SLUG} --template bnb-devnet --account ${TENDERLY_ACCOUNT_ID} --access_key ${TENDERLY_ACCESS_KEY} --return-url)
	export AVALANCHE_RPC_URL := $(shell tenderly devnet spawn-rpc --project ${TENDERLY_PROJECT_SLUG} --template avalanche-devnet --account ${TENDERLY_ACCOUNT_ID} --access_key ${TENDERLY_ACCESS_KEY} --return-url)
	export POLYGON_RPC_URL := $(shell tenderly devnet spawn-rpc --project ${TENDERLY_PROJECT_SLUG} --template polygon-devnet --account ${TENDERLY_ACCOUNT_ID} --access_key ${TENDERLY_ACCESS_KEY} --return-url)
	export ARBITRUM_RPC_URL := $(shell tenderly devnet spawn-rpc --project ${TENDERLY_PROJECT_SLUG} --template arbitrum-devnet --account ${TENDERLY_ACCOUNT_ID} --access_key ${TENDERLY_ACCESS_KEY} --return-url)
	export OPTIMISM_RPC_URL := $(shell tenderly devnet spawn-rpc --project ${TENDERLY_PROJECT_SLUG} --template optimism-devnet --account ${TENDERLY_ACCOUNT_ID} --access_key ${TENDERLY_ACCESS_KEY} --return-url)
	export BASE_RPC_URL := $(shell tenderly devnet spawn-rpc --project ${TENDERLY_PROJECT_SLUG} --template base-devnet --account ${TENDERLY_ACCOUNT_ID} --access_key ${TENDERLY_ACCESS_KEY} --return-url)
	export FANTOM_RPC_URL := $(shell tenderly devnet spawn-rpc --project ${TENDERLY_PROJECT_SLUG} --template fantom-devnet --account ${TENDERLY_ACCOUNT_ID} --access_key ${TENDERLY_ACCESS_KEY} --return-url)
endif

# deps
install:; forge install
update:; forge update

# Build & test
build :; FOUNDRY_PROFILE=production forge build
build-unoptimized :; FOUNDRY_PROFILE=localdev forge build
build-sizes :; FOUNDRY_PROFILE=production forge build --sizes
test-vvv   :; forge test --match-test test_mintSingle_NOT_MINTER -vvv
ftest   :; forge test
test-ci :; forge test --no-match-path "test/invariant/**/*.sol"
coverage :; FOUNDRY_PROFILE=coverage forge coverage --match-path "test/**/*.sol" --report lcov
coverage-t :; FOUNDRY_PROFILE=coverage forge coverage --match-contract RewardsDistributorTests --report lcov
smoke-test   :; forge test --match-contract SmokeTest -vvv
invariant   :; forge test --match-path "test/invariant/**/*.sol" -vvv
invariant-rewards   :; forge test --match-test invariant_tokenBalances -vvv
clean  :; forge clean
snapshot :; forge snapshot
fmt    :; forge fmt && forge fmt test/
ityfuzz :; ityfuzz evm -m -- forge test