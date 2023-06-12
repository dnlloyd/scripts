import boto3

ecr = boto3.client('ecr')
desc_repos_resp = ecr.describe_repositories()

for repository in desc_repos_resp['repositories']:
    repo_name = repository['repositoryName']

    list_images_resp = ecr.list_images(repositoryName=repo_name)
    image_ids = list_images_resp['imageIds']

    if image_ids != []:
        print("deleteing images in repo: " + repo_name)
        print('Images to delete')
        for image in image_ids:
            print(image['imageDigest'] + ':' + image['imageTag'])
        print('')

        ecr.batch_delete_image(repositoryName=repo_name, imageIds=image_ids)
