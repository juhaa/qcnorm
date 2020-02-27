#!/usr/bin/env nextflow
nextflow.preview.dsl=2

// params.num_pc = params.num_pc == null ? 3 : params.num_pc

// Channel
//     .fromPath(params.vcf_file)
//     .ifEmpty { exit 1, "Samples genotype vcf not found: ${params.vcf_file}" } 
//     .set { vcf_file_ch }

// Channel
//     .fromPath(params.ref_genome)
//     .ifEmpty { exit 1, "Reference genotype vcf not found: ${params.ref_genome}" } 
//     .set { ref_genome_ch }

// Channel
//     .fromPath(params.populations_file)
//     .ifEmpty { exit 1, "Populations metadata file not found: ${params.populations_file}" } 
//     .set { populations_file_ch }

// if(params.exclude_population){
//     Channel
//         .fromPath(params.ids_to_remove_file)
//         .ifEmpty { exit 1, "Populations metadata file not found: ${params.ids_to_remove_file}" } 
//         .set { ids_to_remove_file_ch }
// }

// workflow {
//     if(params.study_name=="") {exit 1, "Error: Please provide --study_name parameter. "} 
    
//     pop_assign()
// }
    
Channel.fromPath("test_data/projections_comb.tsv").set {projecions_test_ch}    
workflow pop_assign {
    main:
        test_process(projecions_test_ch)
        // refVCFtoBED(ref_genome_ch)
        // refBedNoDubl = params.exclude_population ? 
        //     removeFamilyFromRef(refVCFtoBED.out, ids_to_remove_file_ch) : 
        //     removeDublFromRef(refVCFtoBED.out)

        // getSNPsFromRef(refBedNoDubl)
        // // getSNPsFromRef.out.ref_snps_list

        // sampleVCftoBED(vcf_file_ch)
        // // sampleVCftoBED.out.sample_bed, 
        // // sampleVCftoBED.out.relatedness_sample_list 

        // calculateRelatednessMatrix(sampleVCftoBED.out.sample_bed, sampleVCftoBED.out.relatedness_sample_list)
        // // calculateRelatednessMatrix.out
        
        // extractSharedSNPsFromSampleGen(sampleVCftoBED.out.sample_bed, 
        //     getSNPsFromRef.out.ref_snps_list)
        // // extractSharedSNPsFromSampleGen.out.sample_gen_overlapped
        // // extractSharedSNPsFromSampleGen.out.sample_gen_overlapped_snplist
        
        // extractSharedSNPsFromRefGen(refBedNoDubl,
        //     extractSharedSNPsFromSampleGen.out.sample_gen_overlapped_snplist)
        // // extractSharedSNPsFromRefGen.out.ref_overlapped
        
        // calcKinsMatrices(extractSharedSNPsFromRefGen.out.ref_overlapped)
        // // calcKinsMatrices.out.ref_overlapped_kins
        
        // calcRefPcaAndLoads(calcKinsMatrices.out.ref_overlapped_kins,
        //     extractSharedSNPsFromRefGen.out.ref_overlapped)
        // // calcRefPcaAndLoads.out.ref_overlapped_loads
        // // calcRefPcaAndLoads.out.ref_overlapped_pca

        // mapSampleGenToRef(extractSharedSNPsFromSampleGen.out.sample_gen_overlapped,
        //     calcRefPcaAndLoads.out.ref_overlapped_loads)
        // // mapSampleGenToRef.out.sample_gen_scores
        // plotPCA(mapSampleGenToRef.out.sample_gen_scores,
        //         calcRefPcaAndLoads.out.ref_overlapped_pca,
        //         populations_file_ch)

    emit:
        projections_ch = test_process.out.pop_assign_projections_ch
}

process refVCFtoBED{
    storeDir "$baseDir/reference_vcf_cache/"
    
    input:
    path "ref.vcf.gz"

    output:
    tuple path('ref.bed'), path('ref.bim'), path('ref.fam')

    script:
    """
    # do ld pruning and save resulted snps in file  
    plink2 --vcf ref.vcf.gz --vcf-half-call h --indep-pairwise 50000 200 0.05 --out ref_pruned_varaints_list --threads ${task.cpus}

    # make bfiles for pruned 1000 genome proj 
    plink2 --vcf ref.vcf.gz --vcf-half-call h --extract ref_pruned_varaints_list.prune.in --make-bed --out ref
    """
}

process removeFamilyFromRef{
    storeDir "$baseDir/reference_vcf_cache/"

    input:
    tuple path('ref.bed'), path('ref.bim'), path('ref.fam')
    path 'ids_to_remove.txt' 

    output:
    tuple path('ref_no_dubl.bed'), path('ref_no_dubl.bim'), path('ref_no_dubl.fam')

    script:
    """
    plink2 --bfile ref --remove-fam ids_to_remove.txt --make-bed --out ref

    # finds dublicate vars
    plink2 --bfile ref --list-duplicate-vars --out dubl

    # delete dublicate vars
    plink2 --bfile ref --exclude dubl.dupvar --snps-only --make-bed --out ref_no_dubl
    """
}

process removeDublFromRef{
    storeDir "$baseDir/reference_vcf_cache/"

    input:
    tuple path('ref.bed'), path('ref.bim'), path('ref.fam')
  
    output:
    tuple path('ref_no_dubl.bed'), path('ref_no_dubl.bim'), path('ref_no_dubl.fam')

    script:
    """
    # finds dublicate vars
    plink2 --bfile ref --list-duplicate-vars --out dubl
    
    # delete dublicate vars
    plink2 --bfile ref --exclude dubl.dupvar --snps-only --make-bed --out ref_no_dubl
    """
}

process getSNPsFromRef{
    storeDir "$baseDir/reference_vcf_cache/"

    input: 
    tuple path('ref_no_dubl.bed'), path('ref_no_dubl.bim'), path('ref_no_dubl.fam')

    output:
    path 'ref_snps_list.snplist', emit: ref_snps_list

    script:
    """
    plink2 --bfile ref_no_dubl --write-snplist --out ref_snps_list --snps-only
    """
}

// convert vcf file to plink binary file (.bed)
process sampleVCftoBED{
    publishDir "${params.outdir}/${params.study_name}/pop_assign", mode: 'copy'
    
    input:
    path 'sample.vcf.gz'

    output:
    tuple path('sample_genotype.bed'), path('sample_genotype.bim'), path('sample_genotype.fam'), emit: sample_bed
    path 'sample_list.txt', emit: relatedness_sample_list

    script:
    """
    #Convert VCF to plink
    plink2 --vcf sample.vcf.gz --out sample_genotype --threads ${task.cpus}
    plink2 --bfile sample_genotype --list-duplicate-vars --out list_dubl
    plink2 --bfile sample_genotype --exclude list_dubl.dupvar --snps-only --make-bed --out sample_genotype

    #Extract sample ids
    bcftools query -l sample.vcf.gz > sample_list.txt
    """
}

process calculateRelatednessMatrix{
    publishDir "${params.outdir}/${params.study_name}/pop_assign", mode: 'copy'

    input:
    tuple path('sample_genotype.bed'), path('sample_genotype.bim'), path('sample_genotype.fam')
    path 'sample_list.txt'

    output:
    path "relatedness_matrix.tsv"

    script:
    """
    #Filter low MAF and low HWE snps
    plink2 --bfile sample_genotype --maf 0.05 --hwe 1e-6 --hwe-all --make-bed --out binary_filtered

    #Perform LD pruning
    plink2 --bfile binary_filtered --indep-pairwise 250 50 0.2 --out pruned_genotypes

    #Make pruned plink file 
    plink2 --bfile binary_filtered --extract pruned_genotypes.prune.in --make-bed --out binary_pruned

    #Calculate relatedness
    plink2 --make-rel square --bfile binary_pruned

    #Format relatedness matrix
    Rscript $baseDir/bin/pop_assign/format_kinship.R \\
        --kinship plink.rel \\
        --fam sample_list.txt \\
        --out relatedness_matrix.tsv
    """
}

process extractSharedSNPsFromSampleGen{
    input:
    tuple path ('sample_genotype.bed'), path('sample_genotype.bim'), path('sample_genotype.fam')
    path 'ref_snps_list.snplist'

    output:
    tuple path('sample_gen_overlapped.bed'), path('sample_gen_overlapped.bim'), path('sample_gen_overlapped.fam'), emit: sample_gen_overlapped
    path 'overlapped_snps.snplist', emit: sample_gen_overlapped_snplist

    // extract snps present in pruned data from new dataset
    // --make-bed makes sure bfiles created!
    script:
    """
    plink2 --bfile sample_genotype --extract ref_snps_list.snplist --make-bed --out sample_gen_overlapped
    plink2 --bfile sample_gen_overlapped --write-snplist --out overlapped_snps
    """
}

process extractSharedSNPsFromRefGen {
    input:
    tuple path('ref.bed'), path('ref.bim'), path('ref.fam')
    path 'overlapped_snps.snplist'

    output:
    tuple path('ref_overlapped.bed'), path('ref_overlapped.bim'), path('ref_overlapped.fam'), emit: ref_overlapped

    script:
    """
    plink2 --bfile ref --extract overlapped_snps.snplist --make-bed --out ref_overlapped
    """
}

process calcKinsMatrices{
    input:
    tuple path('ref_overlapped.bed'), path('ref_overlapped.bim'), path('ref_overlapped.fam')

    output:
    tuple path("ref_overlapped_kins.grm.bin"), path("ref_overlapped_kins.grm.id"), path("ref_overlapped_kins.grm.adjust"), path("ref_overlapped_kins.grm.details"), emit: ref_overlapped_kins
    
    script:
    """
    ldak --calc-kins-direct ref_overlapped_kins --bfile ref_overlapped --ignore-weights YES --power -0.25
    """
}

process calcRefPcaAndLoads{
    publishDir "${params.outdir}/${params.study_name}/pop_assign", mode: 'copy'

    input:
    tuple path("ref_overlapped_kins.grm.bin"), path("ref_overlapped_kins.grm.id"), path("ref_overlapped_kins.grm.adjust"), path("ref_overlapped_kins.grm.details")
    tuple path('ref_overlapped.bed'), path('ref_overlapped.bim'), path('ref_overlapped.fam')

    output:
    path 'ref_overlapped_loads.load', emit: ref_overlapped_loads
    path 'ref_overlapped_pca.vect', emit: ref_overlapped_pca
     
    script: 
    """
    ldak --pca ref_overlapped_pca --grm ref_overlapped_kins --axes ${params.num_pc}
    ldak --calc-pca-loads ref_overlapped_loads --grm ref_overlapped_kins --pcastem ref_overlapped_pca --bfile ref_overlapped
    """
}

process mapSampleGenToRef{
    publishDir "${params.outdir}/${params.study_name}/pop_assign", mode: 'copy'
    
    input:
    tuple path('sample_gen_overlapped.bed'), path('sample_gen_overlapped.bim'), path('sample_gen_overlapped.fam')
    path 'ref_overlapped_loads.load'

    output:
    path 'sample_gen_scores.profile.adj', emit: sample_gen_scores

    script:
    """
    ldak --calc-scores sample_gen_scores --bfile sample_gen_overlapped --scorefile ref_overlapped_loads.load --power 0
    """
}

process plotPCA{
    publishDir "${params.outdir}/${params.study_name}/pop_assign", mode: 'copy'
    
    input:
    path 'sample_gen_scores.profile.adj'
    path 'ref_overlapped_pca.vect'
    path 'samples_data.tsv'

    output:
    path 'plots/*'
    path 'populations.tsv'
    path 'projections_comb.tsv', emit: pop_assign_projections_ch

    script:
    """
    Rscript $baseDir/bin/pop_assign/plot_pca.R ref_overlapped_pca.vect sample_gen_scores.profile.adj samples_data.tsv ${params.study_name}
    """
}


process test_process{
    publishDir "${params.outdir}/${params.study_name}/pop_assign", mode: 'copy'
    
    input:
    path 'projections_comb.tsv'

    output:
    path 'projections_comb.tsv', emit: pop_assign_projections_ch

    script:
    """
    echo "just test script"
    """
}


