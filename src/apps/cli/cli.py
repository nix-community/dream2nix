from cleo import Application

from commands.add import AddCommand
from commands.update import UpdateCommand

application = Application("dream2nix")
application.add(AddCommand())
application.add(UpdateCommand())

if __name__ == '__main__':
  application.run()
