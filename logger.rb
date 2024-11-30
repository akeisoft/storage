require 'thread'

module Logger
  def log(message)
    puts "[#{Time.now}] #{message}"
  end
end

class TaskManager
  include Logger

  def initialize
    @tasks = Queue.new
    @mutex = Mutex.new
  end

  def add_task(task)
    @mutex.synchronize do
      @tasks << task
      log("Task added: #{task[:name]}")
    end
  end

  def execute_tasks
    threads = []
    5.times do
      threads << Thread.new do
        while !@tasks.empty?
          task = nil
          @mutex.synchronize { task = @tasks.pop(true) rescue nil }
          next unless task

          begin
            log("Executing task: #{task[:name]}")
            task[:action].call
            log("Task completed: #{task[:name]}")
          rescue StandardError => e
            log("Error executing task: #{task[:name]} - #{e.message}")
          end
        end
      end
    end
    threads.each(&:join)
  end
end

def process_data(data)
  data.map { |x| x**2 }.select(&:even?).reduce(:+)
end

task_manager = TaskManager.new

task_manager.add_task(name: 'Task 1', action: proc { puts process_data([ 1, 2, 3, 4, 5 ]) })
task_manager.add_task(name: 'Task 2', action: proc { sleep 2; puts 'Hello from Task 2' })
task_manager.add_task(name: 'Task 3', action: proc { raise 'Something went wrong' })
task_manager.add_task(name: 'Task 4', action: proc { puts 'Task 4 is running' })

task_manager.execute_tasks
