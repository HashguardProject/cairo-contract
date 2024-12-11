use starknet::ContractAddress;
use core::traits::Into;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
use core::byte_array::ByteArray;

use project::backupSBTTemplate::IBackupTemplateDispatcher;
use project::backupSBTTemplate::IBackupTemplateDispatcherTrait;
use project::backupSBTTemplate::IERC721Dispatcher;
use project::backupSBTTemplate::IERC721DispatcherTrait;
use project::backupSBTTemplate::IERC721MetadataDispatcher;
use project::backupSBTTemplate::IERC721MetadataDispatcherTrait;
use project::backupSBTTemplate::IERC5192Dispatcher;
use project::backupSBTTemplate::IERC5192DispatcherTrait;

fn deploy_sbt_template(owner: ContractAddress) -> ContractAddress {
    let contract = declare("BackupTemplate").unwrap().contract_class();
    let mut constructor_calldata = array![
        owner.into(),
        'Backup SBT'.into(),
        'BSBT'.into(),
        'ipfs://metadata/'.into()
    ];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

#[test]
fn test_sbt_deployment() {
    let owner = starknet::get_caller_address();
    let contract_address = deploy_sbt_template(owner);
    
    let erc721 = IERC721Dispatcher { contract_address };
    let metadata = IERC721MetadataDispatcher { contract_address };
    let sbt = IERC5192Dispatcher { contract_address };
    
    // Check token ownership
    assert(erc721.balance_of(owner) == 1_u256, 'Wrong balance');
    assert(erc721.owner_of(1_u256) == owner, 'Wrong owner');
    
    // Check metadata
    assert(metadata.name() == 'Backup SBT', 'Wrong name');
    assert(metadata.symbol() == 'BSBT', 'Wrong symbol');
    assert(metadata.token_uri(1_u256) == 'ipfs://metadata/', 'Wrong URI');
    
    // Check soulbound status
    assert(sbt.locked(1_u256), 'Token should be locked');
}

#[test]
#[should_panic(expected: ('Token is Soulbound',))]
fn test_sbt_transfer_prevention() {
    let owner = starknet::get_caller_address();
    let contract_address = deploy_sbt_template(owner);
    
    let erc721 = IERC721Dispatcher { contract_address };
    
    // Attempt to transfer the token
    let recipient = starknet::contract_address_const::<0x123>();
    erc721.transfer_from(owner, recipient, 1_u256);
}

#[test]
#[should_panic(expected: ('Token is Soulbound',))]
fn test_sbt_approval_prevention() {
    let owner = starknet::get_caller_address();
    let contract_address = deploy_sbt_template(owner);
    
    let erc721 = IERC721Dispatcher { contract_address };
    
    // Attempt to approve another address
    let operator = starknet::contract_address_const::<0x123>();
    erc721.approve(operator, 1_u256);
}

#[test]
fn test_sbt_queries() {
    let owner = starknet::get_caller_address();
    let contract_address = deploy_sbt_template(owner);
    
    let erc721 = IERC721Dispatcher { contract_address };
    
    // Check that approvals are always zero/false
    let token_id = 1_u256;
    let operator = starknet::contract_address_const::<0x123>();
    
    assert(erc721.get_approved(token_id).is_zero(), 'Should have no approval');
    assert(!erc721.is_approved_for_all(owner, operator), 'Should not be approved');
}

#[test]
#[should_panic(expected: ('Token ID does not exist',))]
fn test_invalid_token_id() {
    let owner = starknet::get_caller_address();
    let contract_address = deploy_sbt_template(owner);
    
    let erc721 = IERC721Dispatcher { contract_address };
    
    // Try to query non-existent token
    erc721.owner_of(2_u256);
}

#[test]
fn test_backup_with_sbt() {
    let owner = starknet::get_caller_address();
    let contract_address = deploy_sbt_template(owner);
    
    let template = IBackupTemplateDispatcher { contract_address };
    let erc721 = IERC721Dispatcher { contract_address };
    
    // Verify SBT ownership
    assert(erc721.owner_of(1_u256) == owner, 'Wrong token owner');
    
    // Create backup
    template.create_backup(123);
    
    // Verify backup creation
    let last_backup_time = template.get_last_backup_time();
    let backup_data = template.get_backup(last_backup_time);
    assert(backup_data.backup_cid == 123, 'Wrong backup CID');
} 