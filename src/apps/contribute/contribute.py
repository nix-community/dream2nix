import os
import subprocess as sp
from cleo import Application, Command
from cleo.helpers import option


dream2nix_src = "./src"


class ContributeCommand(Command):

    description = (
        "Add a new module to dream2nix by initializing a template"
    )

    name = "contribute"

    options = [
        option("module", None, "Which kind of module to contribute", flag=False),
        option("subsystem", None, "which kind of subsystem", flag=False),
        option("type", None, "pure or impure translator", flag=False),
        option("name", None, "name of the new module", flag=False),
        option(
            "dependency",
            None,
            "Package to require, with an optional version constraint, "
            "e.g. requests:^2.10.0 or requests=2.11.1.",
            flag=False,
            multiple=True,
        ),
    ]


    def handle(self):
        if self.io.is_interactive():
            self.line("")
            self.line(
                "This command will initialize a template for adding a new module to dream2nix"
            )
            self.line("")
        
        module = self.option("module")
        if not module:
            module = self.choice(
                'Select module type',
                ['translator'],
                0
            )
        module = f"{module}s"
        module_dir = dream2nix_src + f"/{module}/"

        subsystem = self.option('subsystem')
        known_subsystems = list(dir for dir in os.listdir(module_dir) if os.path.isdir(module_dir + dir))
        if not subsystem:
            subsystem = self.choice(
                'Select subsystem',
                known_subsystems
                +
                [
                    " -> add new"
                ],
                0
            )
            if subsystem == " -> add new":
                subsystem = self.ask('Please enter the name of a new subsystem:')
                if subsystem in known_subsystems:
                    raise Exception(f"subsystem {subsystem} already exists")

        
        if module == 'translators':
            type = self.option("type")
            if not type:
                type = self.choice(
                    f'Select {module} type',
                    ['impure', 'pure'],
                    0
                )
        
        name = self.option("name")
        if not name:
            name = self.ask('Specify name of new module:')
        
        for path in (
                module_dir + f"{subsystem}",
                module_dir + f"{subsystem}/{type}",
                module_dir + f"{subsystem}/{type}/{name}"):
            if not os.path.isdir(path):
                os.mkdir(path)
        target_file = module_dir + f"{subsystem}/{type}/{name}/default.nix"
        with open(dream2nix_src + f"/templates/{module}/{type}.nix") as template:
            with open(target_file, 'w') as new_file:
                new_file.write(template.read())

        self.line(f"The template has been initialized in {target_file}")
        if self.confirm('Would you like to open it in your default editor now?', True, '(?i)^(y|j)'):
            sp.run(f"{os.environ.get('EDITOR')} {target_file}", shell=True)
        


application = Application("contribute")
application.add(ContributeCommand())

if __name__ == '__main__':
    application.run()
