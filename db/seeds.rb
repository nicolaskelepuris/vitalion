# frozen_string_literal: true

if Card::Record.count.zero?
  Card::StackableWeapon.create(name: 'stackable weapon 1', value: 1, url: 'https://d2quyk7cakk1i6.cloudfront.net/items/weapon-1.png')
  Card::StackableWeapon.create(name: 'stackable weapon 2', value: 2)
  Card::StackableWeapon.create(name: 'stackable weapon 3', value: 3)
  Card::StackableWeapon.create(name: 'stackable weapon 4', value: 4)
  
  Card::Weapon.create(name: 'weapon 1', value: 5)
  Card::Weapon.create(name: 'weapon 2', value: 8)
  Card::Weapon.create(name: 'weapon 3', value: 10)
  Card::Weapon.create(name: 'weapon 4', value: 18)

  Card::Armor.create(name: 'armor 1', value: 3)
  Card::Armor.create(name: 'armor 2', value: 6)
  Card::Armor.create(name: 'armor 3', value: 7)
  Card::Armor.create(name: 'armor 4', value: 9)
  Card::Armor.create(name: 'armor 5', value: 12)

  Card::HealthPotion.create(name: 'health potion 1', value: 2)
  Card::HealthPotion.create(name: 'health potion 2', value: 4)
end
