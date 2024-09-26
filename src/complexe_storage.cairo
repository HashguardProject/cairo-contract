use core::starknet::ContractAddress;

#[starknet::interface]
trait IComplexStorage<TContractState> {
    fn incr_file_number(ref self: TContractState, amount: u128);
    fn get_file_number(self: @TContractState, address: ContractAddress) -> u128;
    fn store_file(ref self: TContractState, cid: u128, key: u128, name: felt252);
    fn replace_file(ref self: TContractState, number: u128, cid: u128, key: u128, name: felt252);
    fn get_file(ref self: TContractState, number: u128) -> (u128, u128, felt252);
}

#[starknet::contract]
mod complex_storage {
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map
    };
    use core::starknet::{ContractAddress, get_caller_address};

    #[storage]
    struct Storage {
        file_number: Map<ContractAddress, u128>,
        file_cid: Map<ContractAddress, Map<u128, u128>>,
        file_key: Map<ContractAddress, Map<u128, u128>>,
        file_name: Map<ContractAddress, Map<u128, felt252>>,
    }

    #[abi(embed_v0)]
    impl ComplexStorage of super::IComplexStorage<ContractState> {
        fn incr_file_number(ref self: ContractState, amount: u128) {
            let caller = get_caller_address();
            self.file_number.entry(caller).write(amount);
        }

        fn get_file_number(self: @ContractState, address: ContractAddress) -> u128 {
            self.file_number.entry(address).read()
        }

        fn store_file(ref self: ContractState, cid: u128, key: u128, name: felt252) {
            let caller = get_caller_address();
            let new_file_number: u128 = self.file_number.entry(caller).read();
            self.file_number.entry(caller).write(new_file_number + 1);
            self.file_cid.entry(caller).entry(new_file_number).write(cid);
            self.file_key.entry(caller).entry(new_file_number).write(key);
            self.file_name.entry(caller).entry(new_file_number).write(name);
        }

        fn replace_file(
            ref self: ContractState, number: u128, cid: u128, key: u128, name: felt252
        ) {
            let caller = get_caller_address();
            let new_file_number: u128 = self.file_number.entry(caller).read();
            if (number > new_file_number) {
                panic!("no file stored at this number");
            }
            self.file_cid.entry(caller).entry(number).write(cid);
            self.file_key.entry(caller).entry(number).write(key);
            self.file_name.entry(caller).entry(number).write(name);
        }

        fn get_file(ref self: ContractState, number: u128) -> (u128, u128, felt252) {
            let caller = get_caller_address();
            let cid = self.file_cid.entry(caller).entry(number).read();
            let key = self.file_key.entry(caller).entry(number).read();
            let name = self.file_name.entry(caller).entry(number).read();
            (cid, key, name)
        }
    }
}
