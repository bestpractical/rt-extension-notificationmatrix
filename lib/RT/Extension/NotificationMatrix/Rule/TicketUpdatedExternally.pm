package RT::Extension::NotificationMatrix::Rule::TicketUpdatedExternally;
use strict;
use warnings;
use base 'RT::Extension::NotificationMatrix::Rule';

use constant NM_Entry => 'TicketUpdatedExternally';

sub ConditionMatched {
    my $self = shift;
    return unless $self->ScripConditionMatched("On Correspond");

    my @groups = ((map { my $g = RT::Group->new($self->CurrentUser);
                         $g->LoadQueueRoleGroup(Queue => $self->TicketObj->QueueObj->Id, Type => $_);
                         $g;
                   } qw(Cc Owner)),
                  (map { my $g = RT::Group->new($self->CurrentUser);
                         $g->LoadTicketRoleGroup(Ticket => $self->TicketObj->Id, Type => $_);
                         $g;
                     } qw(Cc Owner)));

    for (@groups) {
        return if $_->HasMember($self->TransactionObj->CreatorObj->PrincipalId);
    }

    return 1;
}

1;
