package Taxonomy;

use strict;
use warnings;
use BimUtils;

sub new {
	my $class = shift ;
	my $self = { @_ } ;
	bless $self,$class;
	
	$self->init();
    
	return $self;
}

sub init {
	my $self = shift;

	$self->{accession_taxid_file} //= 'none';
	$self->{delimiter_of_accession_and_taxid} //='none';
	$self->{nodes_dmp_file} //='none';
	$self->{names_dmp_file} //='none';

	#taxidと学名またはtaxonと学名を結びつける際に利用するデリミタ
	$self->{x_sci_del_regex} = '\|';
	$self->{x_xci_del} = "|";

	#更新前taxidが入力に含まれていた場合に値が追加される連想配列
	my %old_taxid_hash = ();
	$self->{old_taxid_hash} = \%old_taxid_hash;

	#入力ファイルに含まれるAccessionIDとtaxidを結びつけた連想配列
	$self->{ac_tx_hash} = BimUtils->hash_key_del_val(
		$self->{accession_taxid_file},
		$self->{delimiter_of_accession_and_taxid}
	);

	#指定の引数が入力されたかどうかの確認
	foreach my $t (keys %$self){
		if ($self->{$t} eq 'none'){
            #print "$t\n";
			print "Argument Error\n" ;
			exit;
		}
        
	}

}

sub accession_taxid_file_setter {
	my $self = shift;
	my $new_accession_taxid_file = shift ;
=pod
	Description
	-----------
	メンバ変数のaccession_taxid_fileをセットする関数
	&update_taxid_accession_file()で変更する際に使用する

	Parameters
	----------
	$new_accession_taxid_file: 
	accession_taxid_fileの変更後の値

=cut
	$self->{accession_taxid_file} = $new_accession_taxid_file ;
}

sub accession_taxid_file_getter {
	my $self = shift ;
=pod
	Description
	-----------
	メンバ変数のaccession_taxid_fileを返却する関数

	Returns
	-------
	$self->accession_taxid_file:
	メンバ変数の$accession_taxid_fileの値を返却する
	
=cut
	return $self->{accession_taxid_file};
}

sub toScie_name {
	my $self 	   = shift;
	my $original_file  = shift;
	#my $ndp_delr 	   = shift;
	#my $ndp_del        = shift;
	#my $original_del   = shift;
	my $out_file3_name = shift;

=pod
	Description
	------------
	taxidをscientificname(学名)に変換して出力.

	Parameters
	----------
	$original_file : 変換前のファイル（タクソンに対応するのがtaxid）のパス

	$out_file_name : taxid/タクソンを学名/タクソンに変換して出力するファイルパス

=cut

	#names.dmpファイルからtaxIDと学名を連想配列で紐づける.
	my $hash_ref = name_dmp_parser();

	#taxid/タクソンのファイルから上記で紐づけた連想配列を利用し、
	# 学名/タクソンに変換して出力する.
	open $FH,"<",${original_file} or die "Can't open the original_file!\n";
	open my $OFH,">",${out_file_name} or die "Can't create the ${out_file3_name}\n" ;
	my $ndp_del = $self->{x_xci_del};
	my $ndp_delr = $self->{x_sci_del_regex};
	my ($accessionID,$taxid,$taxon) = ('','','');
	my @list = (); # @list =(taxid/taxon taxid/taxon ...);
	while(my $line=<$FH>){
		chomp $line;
		($accessionID,@list)=split/${original_del}/,$line;
		print $OFH ${accessionID}.${original_del};
		foreach $_(@list){
			($taxid,$taxon)=split/${ndp_delr}/,$_;
			print $OFH $hash_ref->{$taxid}.${ndp_del}.${taxon}.${original_del};
		}
		print $OFH "\n";	
	}
	close $FH;
	close $OFH;

}

sub name_dmp_parser {
	my $self = shift;

=pod
	Description
	-----------
	#names.dmpファイルからtaxIDと学名を連想配列で紐づける.

	Return
	------
	\%hash : taxIDをキー、学名を値とする連想配列の参照

=cut

	open my $FH,"<",$self->{names_dmp_file} or die "Can't open names.dmp\n";
	my %hash=(); #hash{taxid}=対応するタクソンの学名
	my @node=();#(taxID,タクソンの学名,'識別子(scientific nameやtype material')
	my $names_dmp_del = '\|';
	while(my $line=<$FH>){
		chomp $line;
		@node = split/${names_dmp_del}/,$line;
		@node = map{$_ =~s/\t//g;$_}@node[0,1,3];
		if($node[2] eq 'scientific name'){
			$hash{$node[0]} = $node[1];
			next;
		}
	}
	close $FH;
	return \%hash;
}

sub node_dmp_parser {
	my $self = shift;

=pod
	Description
	-----------
	nodes.dmpファイルをパース

	Returns
	------
	$hash_ref : keyは系統の親のtaxid,valueは文字列（"親taxid|子taxid|タクソン"）

=cut

	my %hash=();#%hash =(Parent_taxid=>"Parent_taxid|Child_taxid|Taxon(genus,sfamily...)");
	my $nodes_file_del = '\t\|\t';
	my ($prID,$chID,$taxon)=('','',''); # 1,1,no rank
	my $ndp_del = $self->{x_xci_del};
	open my $FH,"<",$self->{nodes_dmp_file} or die "Can't open nodes.dmp file\n";
	while(my $line=<$FH>){
		chomp $line;
		($prID,$chID,$taxon,@_)=split/${nodes_file_del}/,$line;
		$hash{$prID}= join($ndp_del,($prID,$chID,$taxon));
	}
	close $FH;

	return (\%hash);
}

sub hierarchy_printer {
	my $self = shift ;
	my $out_file1_name 	= shift // 'outA.txt' ;
	my $isScientific_output = shift //  'false' 	;
	#my $acc_tax_ref = shift // 'false' ;#update時に使用

=pod
	Description
	-----------
	AFI19405.1	80325|species	4015|genus	4014|family	41937|order	91836|no rank...
	AccessionID 最下層のtaxid|対応するタクソンから最上層のtaxid|対応するタクソンを出力する.

	Parameters
	-----------
	$out_file1_name : Descriptionで述べた内容を出力する.

	$isScientific_output :  デフォルトではtaxIDと対応するタクソンの組み合わせ
				で出力するがこのtaxIDを学名に変換して出力するかどうか.
				trueで出力、falseで出力しない.
	
=cut

	#my $old_taxid_hash_ref = $self->{old_taxid_hash} ;# taxidが更新されていないAcccessionIDを管理.			　

	#nodes.dmpの解析
	my ($ndp_delr,$ndp_del,$node_parsed_href) = &node_dmp_parser($self);
	open my $OFH,">",${out_file1_name} or die "Can't open ${out_file1_name}\n" ;

	my $output_del = "\t" ;#outfile1_name(出力ファイル)で使用するデリミタ
	foreach my $accessionID (keys %{$$self{ac_tx_hash}}){
		my $taxID = $self->{ac_tx_hash}->{$accessionID} ;
		print "${taxID}\n";

		#子の最下層までループして出力する
		my ($prID,$chID,$taxon)=('','','');
		my @outList = () ;
		my $out = '';
		while(1){
			if(exists $node_parsed_href->{$taxID}){
				($prID,$chID,$taxon)=split/${ndp_delr}/,$node_parsed_href->{$taxID};
				push @outList,join($ndp_del,($prID,$taxon)) ;#"$prID|$taxon"
			}else{
				$self->{old_taxid_hash}->{$accessionID} = $taxID;
				last;
			}
			$taxID = $chID;
			if($chID == 1){
				$out = join($output_del,@outList) ;
				print $OFH "${accessionID}\t${out}\n";
				@outList = ();
				last;
			}
		}
	}
	close $OFH;

	#更新されていないtaxidが存在する場合はリストで出力する.
	my $return_code = 'false';
	my $temp = $self->{old_taxid_hash};
	if(scalar(keys %$temp)){
		$return_code = 'true';
	}


=pod
	#taxidを学名に変換したファイルを出力する(オプションを選択した場合)
	my $out_file2_name = '';
	if($isScientific_output eq 'true'){
		#$out_file2_name : $isScieitific_outputが真の際に出力するファイル名

		&toScie_name(
				$self,
				$out_file1_name,  #変換前のファイル（タクソンに対応するのがtaxid）のパス
				$ndp_delr,		  #taxidと対応するタクソンとのデリミタの正規表現
				$ndp_del,		  #taxidと対応するタクソンとのデリミタ
				$output_del,	  #AccessionIDに対応する全てのtaxid/タクソンを結びつけるデリミタ
				$out_file2_name   #taxid/タクソンを学名/タクソンに変換して出力するファイルパス
			);
	}
=cut

	return $return_code;
}

sub update_taxid_accession_file {
	my $self	= shift;
	# my $out_file = shift; #出力ファイル名
	# my $isToSciname = shift ; #taxidをタクソンに変換するかどうかの確認

=pod
	Description
	-----------
	古いtaxidを新しいtaxidで置き換えてtaxid_accession_fileを
	再出力し,これをTaxonomyオブジェクトのメンバ変数にsetする.

	Parameters
	----------
	$acc_tax_ref : hash_ref = {'AccessionID'=>'taxonomyID'}

=cut

	#merged.dmpより，更新taxidリストを作成
	#update = (old_taxid->new_taxid);
	my $func = sub {};#chompは行わない
	my $update = BimUtils->hash_key_del_val(
			"./data/merged.dmp",
			'\s\|\s',
			$func
		);

	#更新前taxIDのハッシュのリファレンス($self->{old_taxid_hash})
	#を$updateを利用して更新する.
	my ($old_taxid,$new_taxid) = ('','') ;
	foreach my $accid(keys %{$$self{old_taxid_hash}}){
		$old_taxid = $self->{old_taxid_hash}->{$accid};
		$new_taxid = $update->{$old_taxid};

		#update %acc_tax
		$self->{ac_tx_hash}->{$accid} = $new_taxid;
	}

}

1;
