use warnings;
use strict;

package RT::Extension::NotificationMatrix;
our $VERSION = '1.6';

RT::Ruleset->Add(
    Name => 'NotificationMatrix',
    Rules => [
        'RT::Extension::NotificationMatrix::Notify',
    ]);

1;
