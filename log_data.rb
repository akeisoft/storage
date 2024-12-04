require 'set'
require 'sqlite3'

def setup_database(db_path)
  db = SQLite3::Database.new(db_path)
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS large_array (
      id INTEGER PRIMARY KEY,
      value INTEGER
    );
  SQL
  db
end

def save_large_array_to_db(db, array)
  db.transaction do
    array.each do |value|
      db.execute("INSERT INTO large_array (value) VALUES (?)", value)
    end
  end
end

def load_large_array_from_db(db)
  db.execute("SELECT value FROM large_array").flatten
end

db_path = 'large_array.db'
large_array = (1..10_000_000).to_a

db = setup_database(db_path)


save_large_array_to_db(db, large_array)

loaded_array = load_large_array_from_db(db)
puts loaded_array.size


filter = ->(predicate) do
  ->(collection) { collection.select(&predicate) }
end


reduce = ->(operation, initial) do
  ->(collection) { collection.reduce(initial, &operation) }
end

Transaction = Struct.new(:id, :amount, :type, :tags, keyword_init: true)


transactions = [
  Transaction.new(id: 1, amount: 500, type: :income, tags: Set[:salary]),
  Transaction.new(id: 2, amount: -100, type: :expense, tags: Set[:food]),
  Transaction.new(id: 3, amount: -200, type: :expense, tags: Set[:transport]),
  Transaction.new(id: 4, amount: 1000, type: :income, tags: Set[:freelance]),
  Transaction.new(id: 5, amount: -50, type: :expense, tags: Set[:entertainment])
].lazy



filter_by_type = ->(type) do
  filter.call(->(transaction) { transaction.type == type })
end

calculate_total = reduce.call(->(sum, transaction) { sum + transaction.amount }, 0)

group_by_tags = ->(transactions) do
  transactions.each_with_object(Hash.new { |h, k| h[k] = [] }) do |transaction, groups|
    transaction.tags.each { |tag| groups[tag] << transaction }
  end
end


expenses = filter_by_type.call(:expense).call(transactions)
incomes = filter_by_type.call(:income).call(transactions)

total_expenses = calculate_total.call(expenses)
total_income = calculate_total.call(incomes)

grouped_expenses = group_by_tags.call(expenses)

# TESTING:
puts "Total Income: #{total_income}"
puts "Total Expenses: #{total_expenses}"

puts "Expenses by Tags:"
grouped_expenses.each do |tag, transactions|
  total = calculate_total.call(transactions)
  puts "- #{tag}: #{total}"
end

ids_above_threshold = ->(threshold) do
  filter.call(->(transaction) { transaction.amount.abs > threshold })
    .call(transactions)
    .map(&:id)
end

puts "Transactions above 100: #{ids_above_threshold.call(100).to_a}"
