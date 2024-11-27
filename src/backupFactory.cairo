#[starknet::contract]
mod BackupFactory {
    use starknet::ContractAddress;
    use starknet::class_hash::ClassHash;
    use array::ArrayTrait;
    use zeroable::Zeroable;

    #[storage]
    struct Storage {
        backup_template: ClassHash,
        user_backup_contracts: LegacyMap::<ContractAddress, ContractAddress>,
        is_deployed_by_factory: LegacyMap::<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        BackupContractDeployed: BackupContractDeployed,
    }

    #[derive(Drop, starknet::Event)]
    struct BackupContractDeployed {
        #[key]
        user: ContractAddress,
        #[key]
        backup_contract: ContractAddress,
    }

    mod Errors {
        const ALREADY_HAS_BACKUP: felt252 = 'User already has backup contract';
        const INVALID_TEMPLATE: felt252 = 'Invalid template class hash';
        const NOT_FACTORY_DEPLOYED: felt252 = 'Contract not deployed by factory';
        const DEPLOYMENT_FAILED: felt252 = 'Backup contract deployment failed';
    }

    #[constructor]
    fn constructor(ref self: ContractState, template_hash: ClassHash) {
        assert(!template_hash.is_zero(), Errors::INVALID_TEMPLATE);
        self.backup_template.write(template_hash);
    }

    #[external(v0)]
    impl BackupFactoryImpl of super::IBackupFactory<ContractState> {
        fn deploy_backup_contract(ref self: ContractState) -> ContractAddress {
            let caller = starknet::get_caller_address();
            assert(
                self.user_backup_contracts.read(caller).is_zero(),
                Errors::ALREADY_HAS_BACKUP
            );

            // Deploy new backup contract
            let mut constructor_calldata = ArrayTrait::new();
            constructor_calldata.append(caller.into());  // Pass user address to constructor

            match starknet::deploy_syscall(
                self.backup_template.read(),
                0,  // Salt could be derived from user address
                constructor_calldata.span(),
                false
            ) {
                Some(contract_address) => {
                    // Record the deployment
                    self.user_backup_contracts.write(caller, contract_address);
                    self.is_deployed_by_factory.write(contract_address, true);

                    // Emit event
                    self.emit(
                        BackupContractDeployed {
                            user: caller,
                            backup_contract: contract_address,
                        }
                    );

                    contract_address
                }
                None => panic(Errors::DEPLOYMENT_FAILED),
            }
        }

        fn get_user_backup_contract(self: @ContractState, user: ContractAddress) -> ContractAddress {
            self.user_backup_contracts.read(user)
        }

        fn is_factory_deployed(self: @ContractState, contract: ContractAddress) -> bool {
            self.is_deployed_by_factory.read(contract)
        }
    }
}

#[starknet::interface]
trait IBackupFactory<TContractState> {
    fn deploy_backup_contract(ref self: TContractState) -> ContractAddress;
    fn get_user_backup_contract(self: @TContractState, user: ContractAddress) -> ContractAddress;
    fn is_factory_deployed(self: @TContractState, contract: ContractAddress) -> bool;
}
