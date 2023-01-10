# frozen_string_literal: true

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

Card::Record.destroy_all

Card::Record.create(name: 'card 1', attack: 2, defense: 0)
Card::Record.create(name: 'card 2', attack: 5, defense: 0)
Card::Record.create(name: 'card 3', attack: 8, defense: 0)
Card::Record.create(name: 'card 4', attack: 10, defense: 0)
Card::Record.create(name: 'card 5', attack: 18, defense: 0)

Card::Record.create(name: 'card 6', attack: 0, defense: 3)
Card::Record.create(name: 'card 7', attack: 0, defense: 6)
Card::Record.create(name: 'card 8', attack: 0, defense: 7)
Card::Record.create(name: 'card 9', attack: 0, defense: 9)
Card::Record.create(name: 'card 10', attack: 0, defense: 12)
