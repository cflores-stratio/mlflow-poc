import logging
from time import strftime, gmtime


class StratioIntelligenceLogger(logging.StreamHandler):
    def __init__(self):
        super().__init__()

    def emit(self, record):
        """
        Emit a record.

        If a formatter is specified, it is used to format the record.
        The record is then written to the stream with a trailing newline.  If
        exception information is present, it is formatted using
        traceback.print_exception and appended to the stream.  If the stream
        has an 'encoding' attribute, it is used to determine how to do the
        output to the stream.
        """

        if not hasattr(record, "audit_flag"):
            record.audit_flag = 0
        try:
            msg = self.format(record)
            stream = self.stream
            stream.write(msg)
            stream.write(self.terminator)
            self.flush()
        except Exception:
            self.handleError(record)


logging.addLevelName(100, "AUDIT")
# create logger
logger = logging.getLogger('simple_example')
logger.setLevel(logging.DEBUG)

# create console handler and set level to debug
ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)

# create formatter
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')

# add formatter to ch
ch.setFormatter(formatter)

ch_2 = StratioIntelligenceLogger()
ch_2.setLevel(100)

tzoffset = strftime('%z', gmtime())
formatter_2 = logging.Formatter(
    fmt="%(asctime)s.%(msecs).03d" + tzoffset + " %(levelname)s - %(audit_flag)d %(pathname)s %(module)s:%(lineno)d {'@message': '%(message)s'}",
    datefmt="%Y-%m-%dT%H:%M:%S")
ch_2.setFormatter(formatter_2)

# add ch to logger
logger.addHandler(ch)
logger.addHandler(ch_2)

# 'application' code
logger.debug('debug message')
logger.info('info message')
logger.error('error message')
logger.critical('critical message')
logger.audit(100, "este es mi puto mensaje", {"audit_flag": 1})
