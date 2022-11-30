# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

Card::Record.destroy_all
Card.create(name: 'card 1', attack: 2, defense: 0)
Card.create(name: 'card 2', attack: 5, defense: 0)
Card.create(name: 'card 3', attack: 15, defense: 0)
Card.create(name: 'card 4', attack: 0, defense: 1)
Card.create(name: 'card 5', attack: 0, defense: 4)
Card.create(name: 'card 6', attack: 0, defense: 7)
