package  RT::Extension::NotificationMatrix::Rule;
use strict;
use warnings;
use List::MoreUtils qw(part);
use RT::Action::SendEmail;
use base 'RT::Rule';

sub GetExternalRecipients {
    my $self = shift;
    return $self->GetRecipients(1);
}

sub GetRecipients {
    my ($self, $external) = @_;
    my $matrix = RT::Extension::NotificationMatrix->get_queue_matrix($self->TicketObj->QueueObj);

    my $t = $matrix->{$self->NM_Entry} or return;

    my $address;

    $self->ConditionMatched or return;

    my ($include, $exclude) = part { $_ > 0 ? 0 : 1 } @$t;

    for my $g (@$include) {
        my ($class, @addresses) = $self->_AddressesFromGroupWithClass($g, $external);
        $address->{$class}{$_} = 1 for @addresses;
    }

    for my $excluded (map { $self->_AddressesFromGroup(-$_, $external) } @$exclude ) {
        delete $address->{$_}{$excluded} for qw(To Cc Bcc);
    }

    return { map { $_ => [sort keys %{$address->{$_}} ] }
                 qw(To Cc Bcc) };
}

# external : requestor & cc

sub _AddressesFromGroup {
    my ($self, $id, $external) = @_;
    my ($class, @email) = $self->_AddressesFromGroupWithClass($id, $external);
    return @email;
}

sub _AddressesFromGroupWithClass {
    my ($self, $id, $external) = @_;
    my $g = RT::Group->new($self->CurrentUser);
    $g->Load($id);

    my $is_external = $g->Domain eq 'RT::Queue-Role' && ($g->Name eq 'Requestor' || $g->Name eq 'Cc');
    return if $external xor $is_external;

    my @emails = $g->MemberEmailAddresses;
    my $class = 'Bcc';

    if ($g->Domain eq 'RT::Queue-Role') {
        $g->LoadRoleGroup( Object => $self->TicketObj, Name => $g->Name );
        push @emails, $g->MemberEmailAddresses;
        unless (RT->Config->Get('NotificationMatrixAlwaysBcc')) {
            $class = $g->Name eq 'Cc'      ? 'Cc'
                   : $g->Name eq 'AdminCc' ? 'Bcc'
                                           : 'To';
        }
    }

    return ($class, @emails);
}

sub ScripConditionMatched {
    my $self = shift;
    my $name = shift;

    my $ConditionObj = RT::ScripCondition->new( $self->CurrentUser );
    $ConditionObj->Load( $name ) or die;

    my $txn_type = $self->TransactionObj->Type;

    unless (defined $txn_type and length $txn_type) {
        RT->Logger->error(
            sprintf "Empty transaction type in %s for txn %d. Wrong current user?",
                    ref $self, $self->TransactionObj->Id
        );
    }

    return unless( $ConditionObj->ApplicableTransTypes =~ /(?:^|,)(?:Any|\Q$txn_type\E)(?:,|$)/i );
    # Load the scrip's Condition object
    $ConditionObj->LoadCondition(
        ScripObj       => $self,
        TicketObj      => $self->TicketObj,
        TransactionObj => $self->TransactionObj,
    );

    return $ConditionObj->IsApplicable();
}

sub DefaultTemplate {}

sub DefaultExternalTemplate {
    $_[0]->DefaultTemplate;
}

sub SendAsComment { 0 }

sub LoadTemplate {
    my ($self, $external) = @_;
    my $template = RT::Template->new($self->CurrentUser);

    my $name = ref($self);
    $name =~ s/^RT::Extension::NotificationMatrix::Rule::// or die "unknown rule: $name";
    my @templates = $external ? ("$name-External", $self->DefaultExternalTemplate)
                              : ($name,            $self->DefaultTemplate);

    my $queue = $self->TicketObj->QueueObj->Id;

    for my $tname (@templates, 'Transaction') {
        $template->LoadQueueTemplate( Queue => $queue, Name => $tname );
        $template->LoadGlobalTemplate( $tname ) unless $template->Id;
        last if $template->Id;
    }

    unless ($template->Id) {
        die 'Failed to load template for notification rule: '.$name;
    }

    return $template;
}

sub Description {
    my $self = shift;
    my $name = ref($self) || $self;
    $name =~ s/^RT::Extension::NotificationMatrix::Rule::// or die "unknown rule: $name";
    return "Notification for $name";
}

sub PrepareExternal {
    my ($self) = @_;
    my $recipients = $self->GetExternalRecipients or return;

    my $template = $self->LoadTemplate(1);
    # RT::Action weakens the following, so we need to keep additional references
    my $ref = [RT::Scrip->new($self->CurrentUser),
               { _Message_ID => 0},
               $template];
    return $self->_PrepareSendEmail($recipients, $ref);
}

sub PrepareInternal {
    my ($self) = @_;
    my $recipients = $self->GetRecipients or return;

    my $template = $self->LoadTemplate;
    # RT::Action weakens the following, so we need to keep additional references
    my $ref = [RT::Scrip->new($self->CurrentUser),
               { _Message_ID => 0},
               $template];

    return $self->_PrepareSendEmail($recipients, $ref);
}

sub _PrepareSendEmail {
    my ($self, $recipients, $ref) = @_;

    my $email = RT::Action::SendEmail->new( Argument       => undef,
                                            CurrentUser    => $self->CurrentUser,
                                            ScripObj       => $ref->[0],
                                            ScripActionObj => $ref->[1],
                                            TemplateObj    => $ref->[2],
                                            TicketObj      => $self->TicketObj,
                                            TransactionObj => $self->TransactionObj );

    $email->{$_} = $recipients->{$_} for qw(To Cc Bcc);
    if ( RT->Config->Get('UseFriendlyToLine') ) {
        unless (@{$email->{To}}) {
            @{ $email->{'PseudoTo'} } = sprintf RT->Config->Get('FriendlyToLineFormat'), 'notification', $self->TicketObj->Id;
        }
    }

    # Don't notify the actor unless it's the autoreply.
    if (!RT->Config->Get('NotifyActor') &&
        !$self->isa('RT::Extension::NotificationMatrix::Rule::TicketCreated')) {
        my $creatorObj = $self->TransactionObj->CreatorObj;
        my $creator = $creatorObj->EmailAddress() || '';
        @{ $email->{$_} }  = grep ( lc $_ ne lc $creator, @{ $email->{$_} } )
            for qw(To Cc Bcc);
    }

    $email->{__ref} = $ref;

    return $email;
}

sub Prepare {
    my $self = shift;

    $self->{__email} = [($self->PrepareInternal(), $self->PrepareExternal())];

    # Remove any internal recipients from external notifications by cascading
    # down the array of emails
    for my $i (0 .. $#{$self->{__email}}) {
        my $current = $self->{__email}[$i];

        # Mark as seen all addresses at the current level.  Any addresses left
        # in the current level are already not duplicates.
        my %seen = map { lc($_) => 1 }
                   map { @{$current->{$_}} }
                       qw(To Cc Bcc);

        # For all mail below the current, remove seen addresses
        for my $j (++$i .. $#{$self->{__email}}) {
            my $mail = $self->{__email}[$j];
            for my $type (qw(To Cc Bcc)) {
                my @new;

                for my $addr (@{$mail->{$type}}) {
                    # We don't increment $seen here because SendEmail
                    # suppresses duplicates within headers in a single email
                    # later.  We just want to avoid duplicates across mail.
                    if (defined $addr and length $addr and not $seen{lc $addr}) {
                        push @new, $addr;
                    } else {
                        $RT::Logger->info("Removing '$addr' from $type of notification #$j (@{[ref $self]}) because the address was already included in a higher notification");
                    }
                }
                $mail->{$type} = \@new;
            }
        }
    }

    # Prepare all the email actions now that recipients are ready
    for my $email (@{$self->{__email}}) {
        $email->Prepare;

        if ($self->SendAsComment) {
            $email->TemplateObj->MIMEObj->head->set('From', '');
            $email->TemplateObj->MIMEObj->head->set('Reply-To', '');
            $email->SetReturnAddress( is_comment => 1 );
        }
    }

    # These hints are used by PreviewScrips and must be generated after
    # all the Prepares are run
    $self->{hints} = { class => 'SendEmail',
                       recipients => { To =>  [ map { @{$_->{To}} } @{$self->{__email}} ],
                                       Cc =>  [ map { @{$_->{Cc}} } @{$self->{__email}} ],
                                       Bcc => [ map { @{$_->{Bcc}} } @{$self->{__email}} ],
                                   } };

    return 1;
}

sub Commit {
    my $self = shift;
    if ($self->{__email}) {
        $_->Commit for @{$self->{__email}};
    }

}

sub _Stage {
    my $self = shift;
    return RT->Config->Get('NotificationMatrixStage') || 'TransactionCreate';
}

1;
