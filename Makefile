# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

.PHONY: test

# deps
install:; forge install
update:; forge update

# Build & test
build  :; forge build
test   :; forge test
test-erc :; forge test --match-contract MassTransferer
trace-erc :; forge test --match-contract MassTransferer -vvvv
cov-erc :; forge coverage --match-contract MassTransferer
clean  :; forge clean
snapshot :; forge snapshot
fmt    :; forge fm