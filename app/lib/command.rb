class Command
  def self.run(command)
    puts command
    output = `#{command}`

    puts output

    output
  end
end
