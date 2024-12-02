require 'set'

filter = ->(predicate) do
  ->(collection) { collection.select(&predicate) }
end

map = ->(transform) do
  ->(collection) { collection.map(&transform) }
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
