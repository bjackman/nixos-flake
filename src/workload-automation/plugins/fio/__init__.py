import json


from wa import Parameter, Workload


class Fio(Workload):

    name = 'fio'
    description = '''Minimal runner for FIO benchmark.

    This doesn't do any real target setup it just assumes that that the target
    already has everything we need.
    '''

    parameters = [
        Parameter('fstype', kind=str, allowed_values=['tmpfs', 'ext4'],
                  default='tmpfs', description='FS to run benchmark on')
    ]

    def findmnt_fstype(self, target_path: str) -> str:
        output = self.target.execute(f'findmnt --target {target_path} --json')
        obj = json.loads(output)
        if len(obj['filesystems']) != 1:
            raise WorkloadError(f'findmnd returned {len(obj['filesystems'])} filesystems for {target_path!r}')
        return obj['filesystems'][0]['fstype']

    def initialize(self, context):
        super(Fio, self).initialize(context)
        self.target_outdir = self.target.execute("mktemp -d").strip()

        if self.fstype == 'tmpfs':
            self.fio_directory = '/tmp'
        else:
            self.fio_directory = '/var/tmp'
        got_fstype = self.findmnt_fstype(self.fio_directory)
        if got_fstype != self.fstype:
            raise NotImplementedError(
                "This workload doesn't actually know how to setup the FS. " +
                f"It hoped that {self.fio_directory} would be {self.fstype!r} " +
                f"but it was {got_fstype!r}")

    def run(self, context):
        super(Fio, self).run(context)
        self.target.execute(
            f'fio --name=randread_{self.fstype} ' +
            '--rw=randread --size=1G --blocksize=4K --directory=/tmp ' +
            f'--output="{self.target_outdir}/fio_output_{self.fstype}.json" ' +
            '--output-format=json+ ')

    def extract_results(self, context):
        super(Fio, self).extract_results(context)
        # Extract results on the target

    def update_output(self, context):
        super(Fio, self).update_output(context)
        # Update the output within the specified execution context with the
        # metrics and artifacts form this workload iteration.

    def teardown(self, context):
        super(Fio, self).teardown(context)
        self.target.execute(f'rm -rf {self.target_outdir}')
