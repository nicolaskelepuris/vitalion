# frozen_string_literal: true

if Card::Record.count.zero?
  Card::Record.create(name: 'card 1', attack: 2, defense: 0, stackable: true)
  Card::Record.create(name: 'card 2', attack: 3, defense: 0, stackable: true)
  Card::Record.create(name: 'card 3', attack: 4, defense: 0, stackable: true)
  Card::Record.create(name: 'card 5', attack: 5, defense: 0)
  Card::Record.create(name: 'card 6', attack: 8, defense: 0)
  Card::Record.create(name: 'card 7', attack: 10, defense: 0)
  Card::Record.create(name: 'card 8', attack: 18, defense: 0)

  Card::Record.create(name: 'card 9', attack: 0, defense: 3)
  Card::Record.create(name: 'card 10', attack: 0, defense: 6)
  Card::Record.create(name: 'card 11', attack: 0, defense: 7)
  Card::Record.create(name: 'card 12', attack: 0, defense: 9)
  Card::Record.create(name: 'card 13', attack: 0, defense: 12)
end
