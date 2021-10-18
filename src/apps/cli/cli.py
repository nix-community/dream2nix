from cleo import Application

from commands.package import PackageCommand
from commands.update import UpdateCommand

application = Application("package")
application.add(PackageCommand())
application.add(UpdateCommand())

if __name__ == '__main__':
  application.run()
