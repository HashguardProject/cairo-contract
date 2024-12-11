#[starknet::contract]
mod BackupTemplate {
    use starknet::get_block_timestamp;
    use starknet::ContractAddress;
    use starknet::contract_address::ContractAddressZeroable;
    use zeroable::Zeroable;
    use array::ArrayTrait;
    use starknet::get_caller_address;
    use integer::BoundedInt;

    const IERC721_ID: felt252 = 0x80ac58cd;
    const IERC721_METADATA_ID: felt252 = 0x5b5e139f;
    const IERC5192_ID: felt252 = 0xb45a3c0e;

    #[storage]
    struct Storage {
        owner: ContractAddress,
        backup_data: LegacyMap::<u64, BackupData>,  // timestamp -> backup data
        last_backup_time: u64,
        backup_cooldown: u64,
        max_backups: u64,
        name: felt252,
        symbol: felt252,
        token_uri: LegacyMap::<u256, felt252>,
        owners_balance: LegacyMap::<ContractAddress, u256>,
        token_owner: LegacyMap::<u256, ContractAddress>,
        token_approval: LegacyMap::<u256, ContractAddress>,
        operator_approval: LegacyMap::<(ContractAddress, ContractAddress), bool>,
    }

    #[derive(Drop, Serde)]
    struct BackupData {
        backup_cid: felt252,
        timestamp: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        BackupCreated: BackupCreated,
        Transfer: Transfer,
        Locked: Locked,
    }

    #[derive(Drop, starknet::Event)]
    struct BackupCreated {
        backup_cid: felt252,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct Transfer {
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        #[key]
        token_id: u256
    }

    #[derive(Drop, starknet::Event)]
    struct Locked {
        #[key]
        token_id: u256,
        locked: bool
    }

    mod Errors {
        const UNAUTHORIZED: felt252 = 'Only owner can call';
        const BACKUP_TOO_EARLY: felt252 = 'Backup cooldown not elapsed';
        const MAX_BACKUPS_REACHED: felt252 = 'Maximum number of backups reached';
        const INVALID_TOKEN_ID: felt252 = 'Token ID does not exist';
        const SOULBOUND: felt252 = 'Token is Soulbound';
        const ALREADY_MINTED: felt252 = 'Token already minted';
        const WRONG_TOKEN_OWNER: felt252 = 'Wrong token owner';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, 
        owner_address: ContractAddress,
        name: felt252,
        symbol: felt252,
        uri: felt252
    ) {
        self.owner.write(owner_address);
        self.backup_cooldown.write(7 * 24 * 60 * 60); // 1 week
        self.max_backups.write(5); // Default maximum number of backups
        self.name.write(name);
        self.symbol.write(symbol);
        self._mint(owner_address, 1_u256, uri);
        self.emit(Locked { token_id: 1_u256, locked: true });
    }

    #[external(v0)]
    impl BackupTemplateImpl of super::IBackupTemplate<ContractState> {
        fn create_backup(ref self: ContractState, backup_cid: felt252) {
            // Only owner can create backups
            let caller = starknet::get_caller_address();
            assert(caller == self.owner.read(), Errors::UNAUTHORIZED);

            let current_time = get_block_timestamp();
            let last_backup_time = self.last_backup_time.read();

            // Check cooldown
            assert(
                current_time >= last_backup_time + self.backup_cooldown.read(),
                Errors::BACKUP_TOO_EARLY
            );

            // Check if the maximum number of backups is reached
            let backup_keys = self.backup_data.keys();
            if backup_keys.len() >= self.max_backups.read() {
                // Remove the oldest backup
                let oldest_backup_time = backup_keys[0];
                self.backup_data.remove(oldest_backup_time);
            }

            // Store new backup data
            let backup_data = BackupData {
                backup_cid: backup_cid,
                timestamp: current_time,
            };

            self.backup_data.write(current_time, backup_data);
            self.last_backup_time.write(current_time);

            // Emit event
            self.emit(
                BackupCreated {
                    backup_cid: backup_cid,
                    timestamp: current_time,
                }
            );
        }

        fn get_backup(self: @ContractState, timestamp: u64) -> BackupData {
            self.backup_data.read(timestamp)
        }

        fn get_last_backup_time(self: @ContractState) -> u64 {
            self.last_backup_time.read()
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        fn get_backup_cooldown(self: @ContractState) -> u64 {
            self.backup_cooldown.read()
        }

        fn get_max_backups(self: @ContractState) -> u64 {
            self.max_backups.read()
        }

        fn set_new_owner(ref self: ContractState, new_owner: ContractAddress) {
            let caller = starknet::get_caller_address();
            assert(caller == self.owner.read(), Errors::UNAUTHORIZED);
            self.owner.write(new_owner);
        }

        fn set_backup_cooldown(ref self: ContractState, new_cooldown: u64) {
            let caller = starknet::get_caller_address();
            assert(caller == self.owner.read(), Errors::UNAUTHORIZED);
            self.backup_cooldown.write(new_cooldown);
        }

        fn set_max_backups(ref self: ContractState, new_max: u64) {
            let caller = starknet::get_caller_address();
            assert(caller == self.owner.read(), Errors::UNAUTHORIZED);
            self.max_backups.write(new_max);
        }
    }

    #[external(v0)]
    fn transfer(ref self: ContractState, to: ContractAddress) {
        // Always revert transfers - this is what makes it soulbound
        panic_with_felt252('Token is Soulbound');
    }

    #[external(v0)]
    fn get_token_owner(self: @ContractState) -> ContractAddress {
        self.token_owner.read()
    }

    #[external(v0)]
    impl IERC721Impl of IERC721<ContractState> {
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.owners_balance.read(account)
        }

        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            let owner = self.token_owner.read(token_id);
            assert(!owner.is_zero(), Errors::INVALID_TOKEN_ID);
            owner
        }

        fn get_approved(self: @ContractState, token_id: u256) -> ContractAddress {
            assert(!self.token_owner.read(token_id).is_zero(), Errors::INVALID_TOKEN_ID);
            ContractAddress::zero() // Always return zero as transfers are not allowed
        }

        fn is_approved_for_all(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            false // Always return false as transfers are not allowed
        }

        fn transfer_from(
            ref self: ContractState, 
            _from: ContractAddress, 
            _to: ContractAddress, 
            _token_id: u256
        ) {
            panic_with_felt252(Errors::SOULBOUND)
        }

        fn safe_transfer_from(
            ref self: ContractState,
            _from: ContractAddress,
            _to: ContractAddress,
            _token_id: u256,
            _data: Span<felt252>
        ) {
            panic_with_felt252(Errors::SOULBOUND)
        }

        fn approve(ref self: ContractState, _to: ContractAddress, _token_id: u256) {
            panic_with_felt252(Errors::SOULBOUND)
        }

        fn set_approval_for_all(ref self: ContractState, _operator: ContractAddress, _approved: bool) {
            panic_with_felt252(Errors::SOULBOUND)
        }
    }

    #[external(v0)]
    impl IERC721MetadataImpl of IERC721Metadata<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            self.name.read()
        }

        fn symbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }

        fn token_uri(self: @ContractState, token_id: u256) -> felt252 {
            assert(!self.token_owner.read(token_id).is_zero(), Errors::INVALID_TOKEN_ID);
            self.token_uri.read(token_id)
        }
    }

    #[external(v0)]
    impl IERC5192Impl of IERC5192<ContractState> {
        fn locked(self: @ContractState, token_id: u256) -> bool {
            assert(!self.token_owner.read(token_id).is_zero(), Errors::INVALID_TOKEN_ID);
            true // Always locked
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _mint(
            ref self: ContractState,
            to: ContractAddress,
            token_id: u256,
            uri: felt252
        ) {
            assert(!to.is_zero(), 'Invalid recipient');
            assert(self.token_owner.read(token_id).is_zero(), Errors::ALREADY_MINTED);

            self.owners_balance.write(to, 1_u256);
            self.token_owner.write(token_id, to);
            self.token_uri.write(token_id, uri);

            self.emit(Transfer { from: ContractAddress::zero(), to, token_id });
        }
    }
}

#[starknet::interface]
trait IBackupTemplate<TContractState> {
    fn create_backup(ref self: TContractState, backup_cid: felt252);
    fn get_backup(self: @TContractState, timestamp: u64) -> BackupData;
    fn get_last_backup_time(self: @TContractState) -> u64;
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn set_backup_cooldown(ref self: TContractState, new_cooldown: u64);
    fn set_max_backups(ref self: TContractState, new_max: u64);
    fn set_new_owner(ref self: TContractState, new_owner: ContractAddress);
    fn get_backup_cooldown(self: @TContractState) -> u64;
    fn get_max_backups(self: @TContractState) -> u64;
}

#[starknet::interface]
trait IERC721<TContractState> {
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(self: @TContractState, owner: ContractAddress, operator: ContractAddress) -> bool;
    fn transfer_from(ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256);
    fn safe_transfer_from(ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256, data: Span<felt252>);
    fn approve(ref self: TContractState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TContractState, operator: ContractAddress, approved: bool);
}

#[starknet::interface]
trait IERC721Metadata<TContractState> {
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn token_uri(self: @TContractState, token_id: u256) -> felt252;
}

#[starknet::interface]
trait IERC5192<TContractState> {
    fn locked(self: @TContractState, token_id: u256) -> bool;
}
