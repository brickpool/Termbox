## Import

```
use Errno qw( 
  EINPROGRESS
  EISCONN
  ENOTCONN
  ENOMEM
  ENXIO
  ECONNREFUSED
  ENOTTY
  EPIPE
  ENOPROTOOPT
  EPROTOTYPE
  EPROTONOSUPPORT
  EOPNOTSUPP
  EWOULDBLOCK
  EPERM
);
```

## Add POSIX compatible errno to version >= 5.14.4 if required

```
use constant ENOMSG     => exists(&Errno::ENOMSG)     ? &Errno::ENOMSG    : 35;
use constant ECANCELED  => exists(&Errno::ECANCELED)  ? &Errno::ECANCELED : 47;
use constant ENOTSUP    => exists(&Errno::ENOTSUP)    ? &Errno::ENOTSUP   : 48;
use constant ENODATA    => exists(&Errno::ENODATA)    ? &Errno::ENODATA   : 61;
use constant EBADMSG    => exists(&Errno::EBADMSG)    ? &Errno::EBADMSG   : 77;
use constant EPROTO     => exists(&Errno::EPROTO)     ? &Errno::EPROTO    : 71;
use constant EOVERFLOW  => exists(&Errno::EOVERFLOW)  ? &Errno::EOVERFLOW : 79;
use constant EILSEQ     => exists(&Errno::EILSEQ)     ? &Errno::EILSEQ    : 88;
```

## Common function return values unless otherwise noted.

```
use constant {
  TB_OK                   => 0,               # Success
  TB_ERR                  => ENOTSUP,         # Not supported.
  TB_ERR_NEED_MORE        => EINPROGRESS,     # Operation in progress.
  TB_ERR_INIT_ALREADY     => EISCONN,         # Already connected.
  TB_ERR_INIT_OPEN        => ENOTCONN,        # Not connected
  TB_ERR_MEM              => ENOMEM,          # Out of memory
  TB_ERR_NO_EVENT         => ENOMSG,          # No message.
  TB_ERR_NO_TERM          => ENXIO,           # No such device or address.
  TB_ERR_NOT_INIT         => ECONNREFUSED,    # Connection refused.
  TB_ERR_OUT_OF_BOUNDS    => EOVERFLOW,       # Value too large.
  TB_ERR_READ             => EBADMSG,	        # Bad message.
  TB_ERR_RESIZE_IOCTL     => ENOTTY,          # Inappropriate I/O control operation.
  TB_ERR_RESIZE_PIPE      => EPIPE,	          # Broken pipe.
  TB_ERR_RESIZE_SIGACTION => ECANCELED,       # Operation canceled.
  TB_ERR_POLL             => ENODATA,         # No message available.
  TB_ERR_TCGETATTR        => ENOPROTOOPT,     # No protocol option.
  TB_ERR_TCSETATTR        => EPROTOTYPE,      # Wrong protocol type.
  TB_ERR_UNSUPPORTED_TERM => EPROTONOSUPPORT, # Protocol not supported.
  TB_ERR_RESIZE_WRITE     => EOPNOTSUPP,      # Operation not supported.
  TB_ERR_RESIZE_POLL      => EWOULDBLOCK,     # Operation would block.
  TB_ERR_RESIZE_READ      => EPERM,           # Operation not permitted.
  TB_ERR_RESIZE_SSCANF    => EILSEQ,          # Illegal sequence of bytes.
  TB_ERR_CAP_COLLISION    => EPROTO,          # Protocol error.
};
```
