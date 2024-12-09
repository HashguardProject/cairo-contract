#[starknet::contract]
mod BackupTemplate {
    use starknet::get_block_timestamp;
    use starknet::ContractAddress;
    use starknet::contract_address::ContractAddressZeroable;
    use zeroable::Zeroable;
    use array::ArrayTrait;

    #[storage]
    struct Storage {
        owner: ContractAddress,
        backup_data: LegacyMap::<u64, BackupData>,  // timestamp -> backup data
        last_backup_time: u64,
        backup_cooldown: u64,
        max_backups: u64,
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
    }

    #[derive(Drop, starknet::Event)]
    struct BackupCreated {
        backup_cid: felt252,
        timestamp: u64,
    }

    mod Errors {
        const UNAUTHORIZED: felt252 = 'Only owner can call';
        const BACKUP_TOO_EARLY: felt252 = 'Backup cooldown not elapsed';
        const MAX_BACKUPS_REACHED: felt252 = 'Maximum number of backups reached';
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner_address: ContractAddress) {
        self.owner.write(owner_address);
        self.backup_cooldown.write(7 * 24 * 60 * 60); // 1 week
        self.max_backups.write(5); // Default maximum number of backups
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
