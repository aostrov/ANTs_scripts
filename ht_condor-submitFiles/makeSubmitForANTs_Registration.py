import sys

if sys.version_info[0] != 3:
    print("This script requires Python 3")
    exit()


import os
import pathlib


def get_right_stem(folder_path,desired_stem="_01"):
    path_list = os.listdir(folder_path)
    right_paths = []
    for path in path_list:
        path_1 = pathlib.Path(path)
        if ".gz" in str(path_1):
            right_stem = path_1.stem
            right_stem = pathlib.Path(right_stem).stem[-3:]
        else:
            right_stem = path_1.stem[-3:]
        if right_stem == desired_stem:
            right_paths.append(path)

    return right_paths


def check_stem(path):
    if ".gz" in str(path):
        right_stem = path.stem
        right_stem = pathlib.Path(right_stem).stem[:-3]
    else:
        right_stem = path.stem[:-3]

    return right_stem


def get_transf_names(img_list,folder_path):
    img_list_paths = os.listdir(folder_path)
    right_imgs = []
    for img in img_list:
        paired_imgs = []
        path_1 = pathlib.Path(img)
        right_stem = check_stem(path_1)
        for img_path in img_list_paths:
            path_2 = pathlib.Path(img_path)
            right_stem_path = check_stem(path_2)
            if right_stem==right_stem_path:
                paired_imgs.append(str(img_path))
        right_imgs.append(paired_imgs)
    return right_imgs


if __name__=="__main__":
    # Files and paths related to the submit file,
    # can be locally on your computer or remotely on htcondor
    submitFileSaveDirectory = r'/Users/aostrov/Desktop/'
    outputFile = r'testSubmit'

    # Paths relative to your account
    initialdir = "/Volumes/orger/aaron.ostrovsky/tests/multichannelRegs/"
    executable = os.path.join(initialdir,"/commands/","ants_registration.sh")


    '''
    full path to the images directory, relative to the computer running this script
    For best use, this directory should be the one on htcondor from which you
    will be registering these images
    '''
    imagesDir = "/Volumes/orger/aaron.ostrovsky/tests/multichannelRegs/images"

    '''
    The file names for the templates and registration parameters you will
    use for this set of registrations. This can be a single file, or a
    list of files. There must be a least a single file referenced here for
    both the template and the .antsCall file
    '''
    refbrains = ["ASst1R2-GFP2.nrrd"]
    antsCalls = ["ZBB_Burgess.antsCall"]


    '''
    Which, if any, mask file should be used. For now, the mask file will be used
    for the rigid and non-rigid registration steps, and will apply specifically
    to the moving image (ie the template/reference image). Leave the quotes empty
    to skip using a mask.
    '''
    masks = ""

    '''
    Set requested number of CPUs and the total memory to be allocated, in megabytes
    '''
    cpus = 11
    memoryInMb = 60000



    '''
    Everything below here is used to automatically generate the .submit file,
    and bugs aside, should not need to be edited.
    '''

    folder_path = "sample_files"
    terk_images = get_right_stem(imagesDir)
    print("Right names to images:")
    print(terk_images)
    print("*"*100)
    my_images = get_transf_names(terk_images, imagesDir)

    maskTransfer = (" masks/" + masks) if os.path.exists(os.path.join(initialdir,"masks",masks)) & len(masks)>0 else ""
    maskArg = " -x " + masks if os.path.exists(os.path.join(initialdir,"masks",masks)) else ""

    file = open(os.path.join(submitFileSaveDirectory,outputFile + '.submit'),'w+')
    file.write("universe = docker\n")
    file.write("docker_image = docker-registry.champalimaud.pt/ants\n")
    file.write("executable = " + executable + '\n')
    file.write("request_cpus = " + str(cpus)  + '\n')
    file.write("request_memory = " + str(memoryInMb)  + '\n')
    file.write("Error = logs/$(Cluster).$(Process).err" + '\n')
    file.write("Output = logs/$(Cluster).$(Process).out" + '\n')
    file.write("Log = logs/$(Cluster).$(Process).log" + '\n\n')
    file.write("initialdir = " + initialdir + '\n\n')

    for n in range(0,len(my_images)):
        related_images = my_images[n]
        for refbrain in refbrains:
            for antsCall in antsCalls:
                # file.write("Requirements = (HIGHRAM==FALSE)\n")
                file.write("transfer_input_files = refbrain/"
                    + refbrain
                    + ",images/" + ',images/'.join(related_images)
                    + ",commands/"
                    + antsCall
                    + maskTransfer
                    + "\n")
                file.write("transfer_output_files = registration\n")
                file.write("arguments = " + ' '.join([" -f " + refbrain," -m " + terk_images[n]," -a " + antsCall,maskArg])  +"\n")
                file.write("queue\n\n")

    file.close()
