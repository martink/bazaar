package WebGUI::Asset::Wobject::Bazaar;

#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2008 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use strict;
use Tie::IxHash;
use WebGUI::Utility;
use WebGUI::Shop::Vendor;
use WebGUI::User;
use WebGUI::Search;
use WebGUI::Paginator;
use WebGUI::Pluggable;

use base 'WebGUI::Asset::Wobject';


#-------------------------------------------------------------------
sub canEdit {
        my $self    = shift;
        my $userId  = shift     || $self->session->user->userId;
        return (
		(
			(
				$self->session->form->process("func") eq "add" || 
				(
					$self->session->form->process("assetId") eq "new" && 
					$self->session->form->process("func") eq "editSave" && 
					$self->session->form->process("class") =~ m/^WebGUI::Asset::Sku::BazaarItem/
				)
			) && 
			$self->canUpload( $userId )
		) || # account for new items
		$self->SUPER::canEdit( $userId )
	);
}

#-------------------------------------------------------------------

sub canUpload {
	my $self    = shift;
    my $session = $self->session;

    if ( $self->getValue('vendorsOnly') ) {
        my $vendor = WebGUI::Shop::Vendor->newByUserId( $session );
        return 0 unless $vendor;
    }

	return $session->user->isInGroup($self->get('groupToUpload')) || $self->SUPER::canEdit;
}

#-------------------------------------------------------------------
sub canSetVendorPayout {
    my $self = shift;

    return $self->SUPER::canEdit;
}

#-------------------------------------------------------------------

=head2 definition ( )

defines wobject properties for New Wobject instances.  You absolutely need 
this method in your new Wobjects.  If you choose to "autoGenerateForms", the
getEditForm method is unnecessary/redundant/useless.  

=cut

sub definition {
	my $class = shift;
	my $session = shift;
	my $definition = shift;
	my %properties;
	tie %properties, 'Tie::IxHash';
	%properties = (
		groupToUpload => {
			fieldType       => "group",
			defaultValue    => 2,
			label			=> "Group To Upload",
			tab				=> "security",
        },
        vendorsOnly => {
            fieldType       => 'yesNo',
            defaultValue    => 0,
            label           => 'Only allow vendors to upload?',
            tab             => 'security',
        },
        autoCreateVendors => {
            fieldType       => 'yesNo',
            defaultValue    => 1,
            label           => 'Automatically create vendor accounts?',
            tab             => 'security',
        },
		listLimit => {
			fieldType		=> "integer",
			defaultValue	=> 50,
			label			=> "List Limit",
			tab				=> "display",
		},
        templateId => {
            fieldType       => 'template',
            defaultValue    => 'vhNlRmwdrZivIk1IzEpvYQ',
            label           => 'Bazaar template',
            tab             => 'display',
            namespace       => 'Bazaar',
        },
        bazaarItemTemplateId => {
            fieldType       => 'template',
            defaultValue    => 'VlkZo8ew56Yns_6WMIU8BQ',
            label           => 'Bazaar Item template',
            tab             => 'display',
            namespace       => 'BazaarItem',
        },
        searchTemplateId => {
            fieldType       => 'template',
            defaultValue    => 'ddc-E8lgRHBsSzOSr4aNrw',
            label           => 'Search results template',
            tab             => 'display',
            namespace       => 'Bazaar/Search',
        },
        minimumPrice => {
            fieldType       => 'float',
            defaultValue    => 0,
            label           => 'Minimum price for Bazaar Items',
            tab             => 'properties',
        },
        approvalWorkflowId => {
            fieldType       => 'workflow',
            defaultValue    => 'pbworkflow000000000003',
            label           => 'Bazaar Item approval workflow',
            type            => 'WebGUI::VersionTag',
            tab             => 'security',
        },
        defaultVendorPayoutPercentage => {
            fieldType       => 'integer',
            defaultValue    => 0,
            tab             => 'security',
            label           => 'Default vendor payout percentage',
            hoverHelp       => 'This is the vendor percentage that is used by default by bazaar items',
        },
        defaultDownloadPeriod => {
            fieldType       => 'interval',
            tab             => 'properties',
            label           => 'Default download period.',
            defaultValue    => 365 * 24 * 3600,  # 1 year
            hoverHelp       => 'The default period that buyers are able to download their purchase',
        },
        uploaderCanSetDownloadPeriod => {
            fieldType       => 'yesNo',
            tab             => 'properties',
            label           => 'Uploader can set download period',
            defaultValue    => 1,
            hoverHelp       => 'If set to yes, the uploader is allowed to set the download period.',
        },
	);
	push(@{$definition}, {
		assetName=>'Bazaar',
		icon=>'assets.gif',
		autoGenerateForms=>1,
		tableName=>'bazaar',
		className=>'WebGUI::Asset::Wobject::Bazaar',
		properties=>\%properties
		});
        return $class->SUPER::definition($session, $definition);
}


#-------------------------------------------------------------------
sub formatList {
	my $self        = shift;
    my $assetIds    = shift;
    my $title       = shift;
    my $extraParams = shift;

	my $limit       = $self->get('listLimit');
    my $func        = $self->session->form->process('func');
    my $formParams  = join ';', "func=$func", $extraParams;

    my $p = WebGUI::Paginator->new( $self->session, $self->session->url->page($formParams), $limit );
    $p->setDataByArrayRef( $assetIds );

    my $vars = {
        "func_is_$func" => 1,
        title           => $title,
        url             => $self->getUrl,
        results_loop    => $self->generateShortListLoop( $p->getPageData ),
    };

    $p->appendTemplateVars( $vars );
    
    my $template = WebGUI::Asset::Template->new( $self->session, $self->getValue('searchTemplateId') );
    
	return $self->processStyle( $template->process( $vars ) );
}


#-------------------------------------------------------------------
sub getByCreationShortListVars {
    my $self = shift;

    my $assets = $self->getLineage( ['descendants'], { 
        isa             => 'WebGUI::Asset::Sku::BazaarItem',
#        joinClass       => 'WebGUI::Asset::Sku::BazaarItem',
#        whereClause     => "price > 0 and revisionDate > $twoYearsBack",
        orderByClause   => 'creationDate desc',
        limit           => 10,
    } );

    return $self->generateShortListLoop( $assets );
}

#-------------------------------------------------------------------
sub getByDownloadsShortListVars {
    my $self    = shift;
    my $twoYearsBack    = time - 60*60*24*365*2;

    my $assets = $self->getLineage( ['descendants'], { 
        isa             => 'WebGUI::Asset::Sku::BazaarItem',
        joinClass       => 'WebGUI::Asset::Sku::BazaarItem',
        whereClause     => "assetData.revisionDate > $twoYearsBack",
        orderByClause   => 'downloads desc',
        limit           => 10,
    } );

    return $self->generateShortListLoop( $assets );
}

#-------------------------------------------------------------------
sub getByFeaturedShortListVars {
    my $self    = shift;
    my $twoYearsBack    = time - 60*60*24*365*2;

    my $assets = $self->getLineage( ['descendants'], { 
        isa             => 'WebGUI::Asset::Sku::BazaarItem',
        joinClass       => 'WebGUI::Asset::Sku::BazaarItem',
        whereClause     => "price > 0 and assetData.revisionDate > $twoYearsBack",
        orderByClause   => 'assetData.revisionDate desc',
        limit           => 10,
    } );

    return $self->generateShortListLoop( $assets );
}

#-------------------------------------------------------------------
sub getByRatingShortListVars {
    my $self = shift;
    my $twoYearsBack = time - 60*60*24*365*2;

#### This unfortunately doesn't works since you cannot instanciate Aspects on their own.
#    my $assets = $self->getLineage( ['descendants'], { 
#        isa             => 'WebGUI::Asset::Sku::BazaarItem',
#        joinClass       => 'WebGUI::AssetAspect::Comments',
#        whereClause     => "assetData.revisionDate > $twoYearsBack",
#        orderByClause   => 'averageCommentRating desc',
#        limit           => 10,
#    } );

    my $assets = $self->session->db->buildArrayRef( 
        'select distinct assetId from asset left join assetAspectComments using (assetId) '
        ." where revisionDate > $twoYearsBack and parentId=? order by averageCommentRating desc limit 10 ",
        [
            $self->getId,
        ]
    );

    return $self->generateShortListLoop( $assets );
}

#-------------------------------------------------------------------
sub getByRecentShortListVars {
    my $self = shift;

    my $assets = $self->getLineage( ['descendants'], { 
        isa             => 'WebGUI::Asset::Sku::BazaarItem',
#        joinClass       => 'WebGUI::Asset::Sku::BazaarItem',
#        whereClause     => "price > 0 and revisionDate > $twoYearsBack",
        orderByClause   => 'assetData.revisionDate desc',
        limit           => 10,
    } );

    return $self->generateShortListLoop( $assets );
}

#-------------------------------------------------------------------
sub getByViewsShortListVars {
    my $self    = shift;
    my $twoYearsBack    = time - 60*60*24*365*2;

    my $assets = $self->getLineage( ['descendants'], { 
        isa             => 'WebGUI::Asset::Sku::BazaarItem',
        joinClass       => 'WebGUI::Asset::Sku::BazaarItem',
        whereClause     => "assetData.revisionDate > $twoYearsBack",
        orderByClause   => 'views desc',
        limit           => 10,
    } );

    return $self->generateShortListLoop( $assets );
}

#-------------------------------------------------------------------
sub generateShortListLoop {
    my $self        = shift;
    my $assetIds    = shift || [];
    
    my $session     = $self->session;

    my @shortList;
    foreach my $assetId ( @{ $assetIds } ) {
        my $asset   = WebGUI::Asset->newByDynamicClass( $session, $assetId );

        # Skip assets we can't instanciate
        next unless defined $asset;

        # Fetch preview screens
        my (@previewImagesLoop, @previewFilesLoop);

        my $screens = $asset->getScreenStorage;
        foreach my $filename ( @{ $screens->getFiles } ) {
            my $screenProperties = {
                screen_filename     => $filename,
                screen_url          => $screens->getUrl( $filename ),
                screen_isImage      => $screens->isImage( $filename ),
                screen_thumbnailUrl => $screens->getThumbnailUrl( $filename ),
            };
    
            if ( $screenProperties->{ screen_isImage } ) {
                push @previewImagesLoop, $screenProperties;
            }
            else {
                push @previewFilesLoop, $screenProperties;
            }
        }
        
        my $vendor     = WebGUI::Shop::Vendor->new( $session, $asset->get('vendorId') );
        my $vendorName = $vendor->get('name') unless ( WebGUI::Error->caught || $vendor->get('name') eq 'Default Vendor' );

#        my $itemProperties  = $asset->get;
        my $itemProperties  = $asset->getViewVars;
        my %item = map { ("item_$_" => $itemProperties->{ $_ }) } keys %{ $itemProperties };
        $item{ item_price               } = sprintf '%.2f', $item{ item_price };
        $item{ item_title               } = $asset->getTitle;
        $item{ item_url                 } = $asset->getUrl;
        $item{ item_previewImages_loop  } = \@previewImagesLoop;
        $item{ item_previewFiles_loop   } = \@previewFilesLoop;
        $item{ item_rating_icon         } = $asset->getAverageCommentRatingIcon;
        $item{ item_addToCart_form      } = $asset->getAddToCartForm; 
        $item{ item_keyword_loop        } = $asset->getKeywordLoopVars;
        $item{ item_username            } = WebGUI::User->new( $session, $asset->get('ownerUserId') )->username;
        $item{ item_vendorName          } = $vendorName;
        $item{ item_vendor_searchUrl    } = $self->getUrl( 'func=byVendor;vendorId='.$vendor->getId );

        push @shortList, \%item;
    }

    return \@shortList;
}

#-------------------------------------------------------------------
sub getViewVars {
	my $self = shift;
	my $session = $self->session;	

    # Fetch asset properties
    my $vars = $self->get;

    # controls
    $vars->{ adminOn        } = $session->var->isAdminOn;
    $vars->{ controls       } = $self->getToolbar;
    $vars->{ canUpload      } = $self->canUpload;
    $vars->{ upload_url     } = $self->getUrl('func=add;class=WebGUI::Asset::Sku::BazaarItem');
	
	# keywords
	$vars->{ keywords       } = WebGUI::Keyword->new( $session )->generateCloud( {
        startAsset  => $self,
        displayFunc => 'byKeyword',
    } );

	# featured
    $vars->{ byFeatured_url                   } = $self->getUrl('func=byFeatured');
    $vars->{ byFeatured_shortList_loop        } = $self->getByFeaturedShortListVars; 

	# newest
    $vars->{ byCreation_url                   } = $self->getUrl('func=byCreation');
    $vars->{ byCreation_shortList_loop        } = $self->getByCreationShortListVars;

	# most downloaded
    $vars->{ byDownloads_url            } = $self->getUrl('func=byDownloads');
    $vars->{ byDownloads_shortList_loop } = $self->getByDownloadsShortListVars;

	# most highly rated
    $vars->{ byRating_url               } = $self->getUrl('func=byRating');
    $vars->{ byRating_shortList_loop    } = $self->getByRatingShortListVars;

	# most viewed
    $vars->{ byViews_url                } = $self->getUrl('func=byViews');
    $vars->{ byViews_shortList_loop     } = $self->getByViewsShortListVars;

	# most recently updated
    $vars->{ byRecent_url               } = $self->getUrl('func=byRecent');
    $vars->{ byRecent_shortList_loop    } = $self->getByRecentShortListVars;

	return $vars;
}


##-------------------------------------------------------------------
#sub formatShortList {
#	my ($self, $url, $title, $query, $params) = @_;
#	my $out         = q{<fieldset class="bazaarList"><legend><a href="}.$url.q{">}.$title.q{ &raquo;</a></legend>};
#	my $session     = $self->session;
#	my $revisions   = $self->session->db->read($query, $params);
#	my $first = 1;
#
#    while (my ($id) = $revisions->array) {
#		my $asset = WebGUI::Asset::Sku::BazaarItem->new($session, $id);
#		if (defined $asset) {
#			if ($first) {
#				$out .= q{<div class="firstBazaarItem">};
#				my $screens     = $asset->getScreenStorage;
#				my $firstScreen = $screens->getFiles->[0];
#				if ($firstScreen ne "") {
#					$out .= q{<a class="thumbpic" href="}.$asset->getUrl.q{"><img src="}.$screens->getThumbnailUrl($firstScreen).q{" alt="}.$firstScreen.q{" class="thumbnail" /><span><img src="}.$screens->getUrl($firstScreen).q{" /></span></a>};
#				}
#				$out .= q{<a href="}.$asset->getUrl.q{">}.$asset->getTitle.q{</a> - }.$asset->get('synopsis').q{<br />};
#				$out .= q{</div><ul>};
#				$first = 0;
#			}
#			else {
#				$out .= q{<li>&#187;<a href="}.$asset->getUrl.q{">}.$asset->getTitle.q{</a></li>};
#			}
#		}
#	}
#	$out .= q{</ul></fieldset>};
#	return $out;
#}

#-------------------------------------------------------------------
sub prepareView {
	my $self = shift;
	$self->SUPER::prepareView;

    my $template = WebGUI::Asset::Template->new( $self->session, $self->getValue('templateId') );
    $template->prepare;
    $self->{_template} = $template;
}

#-------------------------------------------------------------------
sub processPropertiesFromFormPost {
    my $self = shift;

    my $output = $self->SUPER::processPropertiesFromFormPost;

    my $percentage = $self->session->integer( 'defaultVendorPayoutPercentage' );
    $percentage = 0     if $percentage < 0;
    $percentage = 100   if $percentage > 100;

    $self->update( {
        defaultVendorPayoutPercentage   => $percentage,
    } );
}

#-------------------------------------------------------------------

=head2 view ( )

method called by the www_view method.  Returns a processed template
to be displayed within the page style.  

=cut

sub view {
    my $self = shift;

    my $vars = $self->getViewVars;

    return $self->{_template}->process( $vars );
}


#-------------------------------------------------------------------
sub www_byCreation {
	my $self = shift;
	my $ids = $self->session->db->buildArrayRef("select assetId from asset where parentId=?
		and className like 'WebGUI::Asset::Sku::BazaarItem%'
		order by creationDate desc", [$self->getId]);
	return $self->formatList($ids,'New in the Bazaar');
}

#-------------------------------------------------------------------
sub www_byDownloads {
	my $self = shift;
	my $ids = $self->session->db->buildArrayRef("select distinct assetId from bazaarItem where revisionDate > unix_timestamp() - 60*60*24*365*2 order by downloads desc");
	return $self->formatList($ids,'Most Downloaded');
}

#-------------------------------------------------------------------
sub www_byFeatured {
	my $self = shift;
	my $ids = $self->session->db->buildArrayRef("select distinct assetId from bazaarItem where price > 0 and revisionDate > unix_timestamp() - 60*60*24*365*2 order by revisionDate desc");
	return $self->formatList($ids,'Featured');
}

#-------------------------------------------------------------------
sub www_byKeyword {
	my $self = shift;
	my $word = $self->session->form->get('keyword');
	my $ids = WebGUI::Keyword->new($self->session)->getMatchingAssets({startAsset=>$self, keywords=>[$word]});
	return $self->formatList($ids, q{Keyword: }.$word, "keyword=$word");
}

#-------------------------------------------------------------------
sub www_byProperties {
    my $self = shift;
    my ($form, $db ) = $self->session->quick( qw{ form db } );

    my $searchTerms = $form->paramsHashRef;
    delete $searchTerms->{ func };
    my @searchKeys  = grep { $searchTerms->{ $_ } ne "" } keys %{ $searchTerms };

    my @classes = $db->buildArray( 'select distinct className from asset where lineage like ? and className like ?', [
        $self->get('lineage').'%',
        'WebGUI::Asset::Sku::BazaarItem%',
    ] );

    my (@constraints, @placeHolders, %tables);
    foreach my $class (@classes) {
        my $definition = WebGUI::Pluggable::instanciate( $class, 'definition', [ $self->session ] );
        
        foreach my $part ( @{ $definition } ) {
            my $table = $part->{ tableName };

            foreach my $key ( @searchKeys ) {
                if ( exists $part->{ properties }->{ $key } ) {
                    $tables{ $table } = 1;
                    push @constraints,  "$table.$key = ?";
                    push @placeHolders, $form->process( $key );
                }
            }
        }
    }


    my @tables          = keys %tables;
    my $source          = shift @tables || 'bazaarItem';
    my $previousTable   = $source;

    for my $table ( @tables ) {
        $source .= " join $table on $previousTable.assetId = $table.assetId and $previousTable.revisionDate = $table.revisiondate ";
    }
    my $condition = 'where '. join ' AND ', @constraints if @constraints;

    my $assetIds = $db->buildArrayRef( "select distinct assetId from $source $condition", \@placeHolders );
    return $self->formatList( $assetIds, 'Search Result', join( ';', map { "$_=$searchTerms->{ $_ }" } keys %{ $searchTerms } ) );
}

#-------------------------------------------------------------------
sub www_byRating {
	my $self = shift;
	my $ids = $self->session->db->buildArrayRef("select distinct assetId from bazaarItem left join assetAspectComments using (assetId,revisionDate) where revisionDate > unix_timestamp() - 60*60*24*365*2 order by averageCommentRating desc");
	return $self->formatList($ids, 'Best Rated');
}

#-------------------------------------------------------------------
sub www_byRecent {
	my $self = shift;
	my $ids = $self->session->db->buildArrayRef("select distinct assetId from bazaarItem order by revisionDate desc");
	return $self->formatList($ids, 'Recently Updated');
}

#-------------------------------------------------------------------
sub www_bySearchQuery {
    my $self    = shift;
    my $session = $self->session;

    my $query   = $session->form->process( 'query' );
    my $search  = WebGUI::Search->new( $session );
    $search->search( {
        keywords    => $query,
        lineage     => [ $self->get('lineage') ],
        where       => q{classname like 'WebGUI::Asset::Sku::BazaarItem%'},
    } );
    my $ids = $search->getAssetIds;

    return $self->formatList( $ids, 'Search results', "query=$query" );
}

#-------------------------------------------------------------------
sub www_byViews {
	my $self = shift;
	my $ids = $self->session->db->buildArrayRef("select distinct assetId from bazaarItem where revisionDate > unix_timestamp() - 60*60*24*365*2 order by views desc");
	return $self->formatList($ids,'Most Viewed');
}

#-------------------------------------------------------------------
sub www_byVendor {
	my $self = shift;
	my $vendorId = $self->session->form->get('vendorId');
	my $vendor = WebGUI::Shop::Vendor->new($self->session, $vendorId);
	my $ids = $self->session->db->buildArrayRef("select distinct assetId from bazaarItem left join sku using (assetId, revisionDate) where vendorId=? group by assetId",[$vendorId]);
	return $self->formatList($ids, $vendor->get('name'), "vendorId=$vendorId" );
}

#-------------------------------------------------------------------

=head2 www_editSave ( )

We're extending www_editSave() stop the creation of non-bazaar items as children.

=cut

sub www_editSave {
	my $self    = shift;
    my $session = $self->session;

    my $className   = $session->form->param('class');
    my $func        = $session->form->param('func');

	# Only allow Bazaar Items and friends to be added to a Bazaar.
    if ( $func eq 'add' && $className !~ /^WebGUI::Asset::Sku::BazaarItem/ ) {
		return $self->getParent->www_view;
    }    

    return $self->SUPER::www_editSave(@_);
}



1;
