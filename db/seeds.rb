# frozen_string_literal: true

if Card::Record.count.zero?
  Card::Weapon.create(name: 'weapon 1', value: 2, stackable: true)
  Card::Weapon.create(name: 'weapon 2', value: 3, stackable: true)
  Card::Weapon.create(name: 'weapon 3', value: 4, stackable: true)
  Card::Weapon.create(name: 'weapon 5', value: 5)
  Card::Weapon.create(name: 'weapon 6', value: 8)
  Card::Weapon.create(name: 'weapon 7', value: 10)
  Card::Weapon.create(name: 'weapon 8', value: 18)

  Card::Armor.create(name: 'armor 1', value: 3)
  Card::Armor.create(name: 'armor 2', value: 6)
  Card::Armor.create(name: 'armor 3', value: 7)
  Card::Armor.create(name: 'armor 4', value: 9)
  Card::Armor.create(name: 'armor 5', value: 12)

  Card::HealthPotion.create(name: 'health potion 1', value: 5)
  Card::HealthPotion.create(name: 'health potion 2', value: 10)
  Card::HealthPotion.create(name: 'health potion 3', value: 15)
end
